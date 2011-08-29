class Patient < ActiveRecord::Base
  set_table_name "patient"
  set_primary_key "patient_id"
  include Openmrs

  has_one :person, :foreign_key => :person_id, :conditions => {:voided => 0}
  has_many :patient_identifiers, :foreign_key => :patient_id, :dependent => :destroy, :conditions => {:voided => 0}
  has_many :patient_programs, :conditions => {:voided => 0}
  has_many :programs, :through => :patient_programs
  has_many :relationships, :foreign_key => :person_a, :dependent => :destroy, :conditions => {:voided => 0}
  has_many :orders, :conditions => {:voided => 0}
  has_many :encounters, :conditions => {:voided => 0} do 
    def find_by_date(encounter_date)
      encounter_date = Date.today unless encounter_date
      find(:all, :conditions => ["DATE(encounter_datetime) = DATE(?)", encounter_date]) # Use the SQL DATE function to compare just the date part
    end
  end

  def after_void(reason = nil)
    self.person.void(reason) rescue nil
    self.patient_identifiers.each {|row| row.void(reason) }
    self.patient_programs.each {|row| row.void(reason) }
    self.orders.each {|row| row.void(reason) }
    self.encounters.each {|row| row.void(reason) }
  end

  def current_diagnoses
    self.encounters.current.all(:include => [:observations]).map{|encounter| 
      encounter.observations.all(
        :conditions => ["obs.concept_id = ? OR obs.concept_id = ?", 
          ConceptName.find_by_name("DIAGNOSIS").concept_id,
          ConceptName.find_by_name("DIAGNOSIS, NON-CODED").concept_id])
    }.flatten.compact
  end

  def current_treatment_encounter(date = Time.now())
    type = EncounterType.find_by_name("TREATMENT")
    encounter = encounters.find(:first,:conditions =>["DATE(encounter_datetime) = ? AND encounter_type = ?",date.to_date,type.id])
    encounter ||= encounters.create(:encounter_type => type.id,:encounter_datetime => date)
  end

  def current_dispensation_encounter(date = Time.now())
    type = EncounterType.find_by_name("DISPENSING")
    encounter = encounters.find(:first,:conditions =>["DATE(encounter_datetime) = ? AND encounter_type = ?",date.to_date,type.id])
    encounter ||= encounters.create(:encounter_type => type.id,:encounter_datetime => date)
  end

  # Get the any BMI-related alert for this patient
  def current_bmi_alert
    weight = self.current_weight
    height = self.current_height
    alert = nil
    unless weight == 0 || height == 0
      current_bmi = (weight/(height*height)*10000).round(1);
      if current_bmi <= 18.5 && current_bmi > 17.0
        alert = 'Low BMI: Eligible for counseling'
      elsif current_bmi <= 17.0
        alert = 'Low BMI: Eligible for therapeutic feeding'
      end
    end

    alert
  end
    
  def alerts
    # next appt
    # adherence
    # drug auto-expiry
    # cd4 due
    
    alerts = []
    type = EncounterType.find_by_name("APPOINTMENT")
    next_appt = self.encounters.find_last_by_encounter_type(type.id, :order => "encounter_datetime").observations.last.to_s rescue nil
    alerts << ('Latest ' + next_appt).capitalize unless next_appt.blank?

    encounter_dates = Encounter.find_by_sql("SELECT * FROM encounter WHERE patient_id = #{self.id} AND encounter_type IN (" +
        ("SELECT encounter_type_id FROM encounter_type WHERE name IN ('VITALS', 'TREATMENT', " +
          "'HIV RECEPTION', 'HIV STAGING', 'ART VISIT', 'DISPENSING')") + ")").collect{|e|
      e.encounter_datetime.strftime("%Y-%m-%d")
    }.uniq

    missed_appt = self.encounters.find_last_by_encounter_type(type.id, 
      :conditions => ["NOT (DATE_FORMAT(encounter_datetime, '%Y-%m-%d') IN (?)) AND encounter_datetime < NOW()",
        encounter_dates], :order => "encounter_datetime").observations.last.to_s rescue nil
    alerts << ('Missed ' + missed_appt).capitalize unless missed_appt.blank?

    type = EncounterType.find_by_name("ART ADHERENCE")
    self.encounters.find_last_by_encounter_type(type.id, :order => "encounter_datetime").observations.map do | adh |
      next if adh.value_text.blank?
      alerts << "Adherence: #{adh.order.drug_order.drug.name} (#{adh.value_text}%)"
    end rescue []

    type = EncounterType.find_by_name("DISPENSING")
    self.encounters.find_last_by_encounter_type(type.id, :order => "encounter_datetime").observations.each do | obs |
      next if obs.order.blank? and obs.order.auto_expire_date.blank?
      alerts << "Auto expire date: #{obs.order.drug_order.drug.name} #{obs.order.auto_expire_date.to_date.strftime('%d-%b-%Y')}"
    end rescue []

    # BMI alerts
    if self.person.age >= 15
      bmi_alert = self.current_bmi_alert
      alerts << bmi_alert if bmi_alert
    end

    hiv_status = self.hiv_status
    alerts << "HIV Status : #{hiv_status} more than 3 months" if ("#{hiv_status.gsub(" ",'')}" == 'Negative' && self.months_since_last_hiv_test > 3)
    alerts << "HIV Status : #{hiv_status}" if "#{hiv_status.gsub(" ",'')}" == 'Unknown'
    alerts << "Lab: Expecting submission of sputum" unless self.sputum_orders_without_submission.empty?
    alerts << "Lab: Waiting for sputum results" if self.sputum_submissions_waiting_for_results.empty? &&   !self.recent_sputum_submissions.empty?

    alerts
  end

  def summary
    #    verbiage << "Last seen #{visits.recent(1)}"
    verbiage = []
    verbiage << patient_programs.map{|prog| "Started #{prog.program.name.humanize} #{prog.date_enrolled.strftime('%b-%Y')}" rescue nil }
    verbiage << orders.unfinished.prescriptions.map{|presc| presc.to_s}
    verbiage.flatten.compact.join(', ') 
  end

  def national_id(force = true)
    id = self.patient_identifiers.find_by_identifier_type(PatientIdentifierType.find_by_name("National id").id).identifier rescue nil
    return id unless force
    id ||= PatientIdentifierType.find_by_name("National id").next_identifier(:patient => self).identifier
    id
  end

  def national_id_with_dashes(force = true)
    id = self.national_id(force)
    id[0..4] + "-" + id[5..8] + "-" + id[9..-1] rescue id
  end

  def demographics_label
    demographics = Mastercard.demographics(self)
    hiv_staging = Encounter.find(:last,:conditions =>["encounter_type = ? and patient_id = ?",
        EncounterType.find_by_name("HIV Staging").id,self.id])

    tb_within_last_two_yrs = "tb within last 2 yrs" unless demographics.tb_within_last_two_yrs.blank?
    eptb = "eptb" unless demographics.eptb.blank?
    pulmonary_tb = "Pulmonary tb" unless demographics.pulmonary_tb.blank?
 
    cd4_count_date = nil ; cd4_count = nil ; pregnant = 'N/A'

    (hiv_staging.observations).map do | obs |
      concept_name = obs.to_s.split(':')[0].strip rescue nil
      next if concept_name.blank?
      case concept_name
      when 'CD4 COUNT DATETIME'
        cd4_count_date = obs.value_datetime.to_date
      when 'CD4 COUNT'
        cd4_count = obs.value_numeric
      when 'IS PATIENT PREGNANT?'
        pregnant = obs.to_s.split(':')[1] rescue nil
      end
    end rescue []

    phone_numbers = self.person.phone_numbers
    phone_number = phone_numbers["Office phone number"] if not phone_numbers["Office phone number"].downcase == "not available" and not phone_numbers["Office phone number"].downcase == "unknown" rescue nil
    phone_number= phone_numbers["Home phone number"] if not phone_numbers["Home phone number"].downcase == "not available" and not phone_numbers["Home phone number"].downcase == "unknown" rescue nil
    phone_number = phone_numbers["Cell phone number"] if not phone_numbers["Cell phone number"].downcase == "not available" and not phone_numbers["Cell phone number"].downcase == "unknown" rescue nil


    label = ZebraPrinter::StandardLabel.new
    label.draw_text("Printed on: #{Date.today.strftime('%A, %d-%b-%Y')}",450,300,0,1,1,1,false)
    label.draw_text("#{demographics.arv_number}",575,30,0,3,1,1,false)
    label.draw_text("PATIENT DETAILS",25,30,0,3,1,1,false)
    label.draw_text("Name:   #{demographics.name} (#{demographics.sex})",25,60,0,3,1,1,false)
    label.draw_text("DOB:    #{self.person.birthdate_formatted}",25,90,0,3,1,1,false)
    label.draw_text("Phone: #{phone_number}",25,120,0,3,1,1,false)
    if demographics.address.length > 48
      label.draw_text("Addr:  #{demographics.address[0..47]}",25,150,0,3,1,1,false)
      label.draw_text("    :  #{demographics.address[48..-1]}",25,180,0,3,1,1,false)
      last_line = 180
    else
      label.draw_text("Addr:  #{demographics.address}",25,150,0,3,1,1,false)
      last_line = 150
    end  

    if last_line == 180 and demographics.guardian.length < 48
      label.draw_text("Guard: #{demographics.guardian}",25,210,0,3,1,1,false)
      last_line = 210
    elsif last_line == 180 and demographics.guardian.length > 48
      label.draw_text("Guard: #{demographics.guardian[0..47]}",25,210,0,3,1,1,false)
      label.draw_text("     : #{demographics.guardian[48..-1]}",25,240,0,3,1,1,false)
      last_line = 240
    elsif last_line == 150 and demographics.guardian.length > 48
      label.draw_text("Guard: #{demographics.guardian[0..47]}",25,180,0,3,1,1,false)
      label.draw_text("     : #{demographics.guardian[48..-1]}",25,210,0,3,1,1,false)
      last_line = 210
    elsif last_line == 150 and demographics.guardian.length < 48
      label.draw_text("Guard: #{demographics.guardian}",25,180,0,3,1,1,false)
      last_line = 180
    end  
   
    label.draw_text("TI:    #{demographics.transfer_in ||= 'No'}",25,last_line+=30,0,3,1,1,false)
    label.draw_text("FUP:   (#{demographics.agrees_to_followup})",25,last_line+=30,0,3,1,1,false)

      
    label2 = ZebraPrinter::StandardLabel.new
    #Vertical lines
=begin
     label2.draw_line(45,40,5,242)
     label2.draw_line(805,40,5,242)
     label2.draw_line(365,40,5,242)
     label2.draw_line(575,40,5,242)
    
     #horizontal lines
     label2.draw_line(45,40,795,3)
     label2.draw_line(45,80,795,3)
     label2.draw_line(45,120,795,3)
     label2.draw_line(45,200,795,3)
     label2.draw_line(45,240,795,3)
     label2.draw_line(45,280,795,3)
=end
    label2.draw_line(25,170,795,3)
    #label data
    label2.draw_text("STATUS AT ART INITIATION",25,30,0,3,1,1,false)
    label2.draw_text("(DSA:#{self.date_started_art.strftime('%d-%b-%Y') rescue 'N/A'})",370,30,0,2,1,1,false)
    label2.draw_text("#{demographics.arv_number}",580,20,0,3,1,1,false)
    label2.draw_text("Printed on: #{Date.today.strftime('%A, %d-%b-%Y')}",25,300,0,1,1,1,false)

    label2.draw_text("RFS: #{demographics.reason_for_art_eligibility}",25,70,0,2,1,1,false)
    label2.draw_text("#{cd4_count} #{cd4_count_date}",25,110,0,2,1,1,false)
    label2.draw_text("1st + Test: #{demographics.hiv_test_date}",25,150,0,2,1,1,false)

    label2.draw_text("TB: #{tb_within_last_two_yrs} #{eptb} #{pulmonary_tb}",380,70,0,2,1,1,false)
    label2.draw_text("KS:#{demographics.ks rescue nil}",380,110,0,2,1,1,false)
    label2.draw_text("Preg:#{pregnant}",380,150,0,2,1,1,false)
    label2.draw_text("#{demographics.first_line_drugs.join(',')[0..32] rescue nil}",25,190,0,2,1,1,false)
    label2.draw_text("#{demographics.alt_first_line_drugs.join(',')[0..32] rescue nil}",25,230,0,2,1,1,false)
    label2.draw_text("#{demographics.second_line_drugs.join(',')[0..32] rescue nil}",25,270,0,2,1,1,false)

    label2.draw_text("HEIGHT: #{self.initial_height}",570,70,0,2,1,1,false)
    label2.draw_text("WEIGHT: #{self.initial_weight}",570,110,0,2,1,1,false)
    label2.draw_text("Init Age: #{self.age_at_initiation(demographics.date_of_first_line_regimen) rescue nil}",570,150,0,2,1,1,false)

    line = 190
    extra_lines = []
    label2.draw_text("STAGE DEFINING CONDITIONS",450,190,0,3,1,1,false)
    (hiv_staging.observations).each{|obs|
      name = obs.to_s.split(':')[0].strip rescue nil
      condition = obs.to_s.split(':')[1].strip.humanize rescue nil
      next unless name == 'WHO STAGES CRITERIA PRESENT'
      line+=25
      if line <= 290
        label2.draw_text(condition[0..35],450,line,0,1,1,1,false) 
      end
      extra_lines << condition[0..79] if line > 290
    } rescue []

    if line > 310 and !extra_lines.blank?
      line = 30
      label3 = ZebraPrinter::StandardLabel.new
      label3.draw_text("STAGE DEFINING CONDITIONS",25,line,0,3,1,1,false)
      label3.draw_text("#{self.arv_number}",370,line,0,2,1,1,false)
      label3.draw_text("Printed on: #{Date.today.strftime('%A, %d-%b-%Y')}",450,300,0,1,1,1,false)
      extra_lines.each{|condition|
        label3.draw_text(condition,25,line+=30,0,2,1,1,false)
      } rescue []
    end
    return "#{label.print(1)} #{label2.print(1)} #{label3.print(1)}" if !extra_lines.blank?
    return "#{label.print(1)} #{label2.print(1)}"
  end

  def national_id_label
    return unless self.national_id
    sex =  self.person.gender.match(/F/i) ? "(F)" : "(M)"
    address = self.person.address.strip[0..24].humanize rescue ""
    label = ZebraPrinter::StandardLabel.new
    label.font_size = 2
    label.font_horizontal_multiplier = 2
    label.font_vertical_multiplier = 2
    label.left_margin = 50
    label.draw_barcode(50,180,0,1,5,15,120,false,"#{self.national_id}")
    label.draw_multi_text("#{self.person.name.titleize}")
    label.draw_multi_text("#{self.national_id_with_dashes} #{self.person.birthdate_formatted}#{sex}")
    label.draw_multi_text("#{address}")
    label.print(1)
  end
  
   def lab_orders_label
    lab_orders = Encounter.find(:last,:conditions =>["encounter_type = ? and patient_id = ?",
        EncounterType.find_by_name("LAB ORDERS").id,self.id]).observations
      labels = []
      i = 0

      while i <= lab_orders.size do
        accession_number = "#{lab_orders[i].accession_number rescue nil}"

        if accession_number != ""
          label = 'label' + i.to_s
          label = ZebraPrinter::StandardLabel.new
          label.font_size = 2
          label.font_horizontal_multiplier = 2
          label.font_vertical_multiplier = 2
          label.left_margin = 50
          label.draw_barcode(50,180,0,1,5,15,120,false,"#{accession_number}")
          label.draw_multi_text("#{self.person.name.titleize.delete("'")} #{self.national_id_with_dashes}")
          label.draw_multi_text("#{lab_orders[i].name rescue nil}")
          label.draw_multi_text("#{accession_number rescue nil}")
          label.draw_multi_text("#{DateTime.now.strftime("%d-%b-%Y %H:%M")}")
          labels << label
          end
          i = i + 1
      end

      print_labels = []
      label = 0
      while label <= labels.size
        print_labels << labels[label].print(1) if labels[label] != nil
        label = label + 1
      end

      return print_labels
  end

  def filing_number_label(num = 1)
    file = self.get_identifier('Filing Number')[0..9]
    file_type = file.strip[3..4]
    version_number=file.strip[2..2]
    number = file
    len = number.length - 5
    number = number[len..len] + "   " + number[(len + 1)..(len + 2)]  + " " +  number[(len + 3)..(number.length)]

    label = ZebraPrinter::StandardLabel.new
    label.draw_text("#{number}",75, 30, 0, 4, 4, 4, false)
    label.draw_text("Filing area #{file_type}",75, 150, 0, 2, 2, 2, false)
    label.draw_text("Version number: #{version_number}",75, 200, 0, 2, 2, 2, false)
    label.print(num)
  end  

  def visit_label(date = Date.today)
    result = Location.current_location.name.match(/outpatient/i).nil?
    if result == false
      return Mastercard.mastercard_visit_label(self,date)
    else
      label = ZebraPrinter::StandardLabel.new
      label.font_size = 3
      label.font_horizontal_multiplier = 1
      label.font_vertical_multiplier = 1
      label.left_margin = 50
      encs = encounters.find(:all,:conditions =>["DATE(encounter_datetime) = ?",date])
      return nil if encs.blank?

      label.draw_multi_text("Visit: #{encs.first.encounter_datetime.strftime("%d/%b/%Y %H:%M")}", :font_reverse => true)
      encs.each {|encounter|
        next if encounter.name.humanize == "Registration"
        label.draw_multi_text("#{encounter.name.humanize}: #{encounter.to_s}", :font_reverse => false)
      }
      label.print(1)
    end
  end

  def get_identifier(type = 'National id')
    identifier_type = PatientIdentifierType.find_by_name(type)
    return if identifier_type.blank?
    identifiers = self.patient_identifiers.find_all_by_identifier_type(identifier_type.id)
    return if identifiers.blank?
    identifiers.map{|i|i.identifier}[0] rescue nil
  end

  def current_weight
    obs = person.observations.recent(1).question("WEIGHT (KG)").all
    obs.first.value_numeric rescue 0
  end
  
  def current_weight
    obs = person.observations.recent(1).question("WEIGHT (KG)").all
    obs.first.value_numeric rescue 0
  end
  
  def current_height
    obs = person.observations.recent(1).question("HEIGHT (CM)").all
    obs.first.value_numeric rescue 0
  end
  
  def initial_weight
    obs = person.observations.old(1).question("WEIGHT (KG)").all
    obs.last.value_numeric rescue 0
  end
  
  def initial_height
    obs = person.observations.old(1).question("HEIGHT (CM)").all
    obs.last.value_numeric rescue 0
  end

  def initial_bmi
    obs = person.observations.old(1).question("BMI").all
    obs.last.value_numeric rescue nil
  end

  def min_weight
    WeightHeight.min_weight(person.gender, person.age_in_months).to_f
  end
  
  def max_weight
    WeightHeight.max_weight(person.gender, person.age_in_months).to_f
  end
  
  def min_height
    WeightHeight.min_height(person.gender, person.age_in_months).to_f
  end
  
  def max_height
    WeightHeight.max_height(person.gender, person.age_in_months).to_f
  end
  
  def given_arvs_before?
    self.orders.each{|order|
      drug_order = order.drug_order
      next if drug_order == nil
      next if drug_order.quantity == nil
      next unless drug_order.quantity > 0
      return true if drug_order.drug.arv?
    }
    false
  end

  def name
    "#{self.person.name}"
  end

  def self.dead_with_visits(start_date, end_date)
    national_identifier_id  = PatientIdentifierType.find_by_name('National id').patient_identifier_type_id
    arv_number_id           = PatientIdentifierType.find_by_name('ARV Number').patient_identifier_type_id
    patient_died_concept    = ConceptName.find_by_name('PATIENT DIED').concept_id

    dead_patients = "SELECT dead_patient_program.patient_program_id,
    dead_state.state, dead_patient_program.patient_id, dead_state.date_changed
    FROM patient_state dead_state INNER JOIN patient_program dead_patient_program
    ON   dead_state.patient_program_id = dead_patient_program.patient_program_id
    WHERE  EXISTS
      (SELECT * FROM program_workflow_state p
        WHERE dead_state.state = program_workflow_state_id AND concept_id = #{patient_died_concept})
          AND dead_state.date_changed >='#{start_date}' AND dead_state.date_changed <= '#{end_date}'"

    living_patients = "SELECT living_patient_program.patient_program_id,
    living_state.state, living_patient_program.patient_id, living_state.date_changed
    FROM patient_state living_state
    INNER JOIN patient_program living_patient_program
    ON living_state.patient_program_id = living_patient_program.patient_program_id
    WHERE  NOT EXISTS
      (SELECT * FROM program_workflow_state p
        WHERE living_state.state = program_workflow_state_id AND concept_id =  #{patient_died_concept})"

    dead_patients_with_observations_visits = "SELECT death_observations.person_id,death_observations.obs_datetime AS date_of_death, active_visits.obs_datetime AS date_living
    FROM obs active_visits INNER JOIN obs death_observations
    ON death_observations.person_id = active_visits.person_id
    WHERE death_observations.concept_id != active_visits.concept_id AND death_observations.concept_id =  #{patient_died_concept} AND death_observations.obs_datetime < active_visits.obs_datetime
      AND death_observations.obs_datetime >='#{start_date}' AND death_observations.obs_datetime <= '#{end_date}'"

    all_dead_patients_with_visits = " SELECT dead.patient_id, dead.date_changed AS date_of_death, living.date_changed
    FROM (#{dead_patients}) dead,  (#{living_patients}) living
    WHERE living.patient_id = dead.patient_id AND dead.date_changed < living.date_changed
    UNION ALL #{dead_patients_with_observations_visits}"

    patients = self.find_by_sql([all_dead_patients_with_visits])
    patients_data  = []
    patients.each do |patient_data_row|
      patient        = Person.find(patient_data_row[:patient_id].to_i)
      national_id    = PatientIdentifier.identifier(patient_data_row[:patient_id], national_identifier_id).identifier rescue ""
      arv_number     = PatientIdentifier.identifier(patient_data_row[:patient_id], arv_number_id).identifier rescue ""
      patients_data <<[patient_data_row[:patient_id], arv_number, patient.name,
        national_id,patient.gender,patient.age,patient.birthdate, patient.phone_numbers, patient_data_row[:date_changed]]
    end
    patients_data
  end

  def self.males_allegedly_pregnant(start_date, end_date)
    national_identifier_id  = PatientIdentifierType.find_by_name('National id').patient_identifier_type_id
    arv_number_id           = PatientIdentifierType.find_by_name('ARV Number').patient_identifier_type_id
    pregnant_patient_concept_id = ConceptName.find_by_name('PATIENT PREGNANT').concept_id

    patients = PatientIdentifier.find_by_sql(["SELECT person.person_id,obs.obs_datetime
                                   FROM obs INNER JOIN person
                                   ON obs.person_id = person.person_id
                                   WHERE person.gender = 'M' AND
                                   obs.concept_id = ? AND obs.obs_datetime >= ? AND obs.obs_datetime <= ?",
        pregnant_patient_concept_id, '2008-12-23 00:00:00', end_date])

    patients_data  = []
    patients.each do |patient_data_row|
      patient        = Person.find(patient_data_row[:person_id].to_i)
      national_id    = PatientIdentifier.identifier(patient_data_row[:person_id], national_identifier_id).identifier rescue ""
      arv_number     = PatientIdentifier.identifier(patient_data_row[:person_id], arv_number_id).identifier rescue ""
      patients_data <<[patient_data_row[:person_id], arv_number, patient.name,
        national_id,patient.gender,patient.age,patient.birthdate, patient.phone_numbers, patient_data_row[:obs_datetime]]
    end
    patients_data
  end

  def self.with_drug_start_dates_less_than_program_enrollment_dates(start_date, end_date)

    arv_drugs_concepts      = Drug.arv_drugs.inject([]) {|result, drug| result << drug.concept_id}
    on_arv_concept_id       = ConceptName.find_by_name('ON ANTIRETROVIRALS').concept_id
    hvi_program_id          = Program.find_by_name('HIV PROGRAM').program_id
    national_identifier_id  = PatientIdentifierType.find_by_name('National id').patient_identifier_type_id
    arv_number_id           = PatientIdentifierType.find_by_name('ARV Number').patient_identifier_type_id

    patients_on_antiretrovirals_sql = "
         (SELECT p.patient_id, s.date_created as Date_Started_ARV
          FROM patient_program p INNER JOIN patient_state s
          ON  p.patient_program_id = s.patient_program_id
          WHERE s.state IN (SELECT program_workflow_state_id
                            FROM program_workflow_state g
                            WHERE g.concept_id = #{on_arv_concept_id})
                            AND p.program_id = #{hvi_program_id}
         ) patients_on_antiretrovirals"

    antiretrovirals_obs_sql = "
         (SELECT * FROM obs
          WHERE  value_drug IN (SELECT drug_id FROM drug
          WHERE concept_id IN ( #{arv_drugs_concepts.join(', ')} ) )
         ) antiretrovirals_obs"

    drug_start_dates_less_than_program_enrollment_dates_sql= "
      SELECT patients_on_antiretrovirals.patient_id, patients_on_antiretrovirals.date_started_ARV,
             antiretrovirals_obs.obs_datetime, antiretrovirals_obs.value_drug
      FROM #{patients_on_antiretrovirals_sql}, #{antiretrovirals_obs_sql}
      WHERE patients_on_antiretrovirals.Date_Started_ARV > antiretrovirals_obs.obs_datetime
            AND patients_on_antiretrovirals.patient_id = antiretrovirals_obs.person_id
            AND patients_on_antiretrovirals.Date_Started_ARV >='#{start_date}' AND patients_on_antiretrovirals.Date_Started_ARV <= '#{end_date}'"

    patients       = self.find_by_sql(drug_start_dates_less_than_program_enrollment_dates_sql)
    patients_data  = []
    patients.each do |patient_data_row|
      patient     = Person.find(patient_data_row[:patient_id].to_i)
      national_id = PatientIdentifier.identifier(patient_data_row[:patient_id], national_identifier_id).identifier rescue ""
      arv_number  = PatientIdentifier.identifier(patient_data_row[:patient_id], arv_number_id).identifier rescue ""
      patients_data <<[patient_data_row[:patient_id], arv_number, patient.name,
        national_id,patient.gender,patient.age,patient.birthdate, patient.phone_numbers, patient_data_row[:date_started_ARV]]
    end
    patients_data
  end

  def self.appointment_dates(start_date, end_date = nil)

    end_date = start_date if end_date.nil?

    appointment_date_concept_id = Concept.find_by_name("APPOINTMENT DATE").concept_id rescue nil

    appointments = Patient.find(:all,
      :joins      => 'INNER JOIN obs ON patient.patient_id = obs.person_id',
      :conditions => ["DATE(obs.value_datetime) >= ? AND DATE(obs.value_datetime) <= ? AND obs.concept_id = ? AND obs.voided = 0", start_date.to_date, end_date.to_date, appointment_date_concept_id],
      :group      => "obs.person_id")

    appointments
  end

  def arv_number
    arv_number_id = PatientIdentifierType.find_by_name('ARV Number').patient_identifier_type_id
    PatientIdentifier.identifier(self.patient_id, arv_number_id).identifier rescue nil
  end

  def age_at_initiation(initiation_date = nil)
    patient = Person.find(self.id)
    return patient.age(initiation_date) unless initiation_date.nil?
  end

  def set_received_regimen(encounter,prescription)
    dispense_finish = true ; dispensed_drugs_concept_ids = []
    
    prescription.orders.each do | order |
      next if not order.drug_order.drug.arv?
      dispensed_drugs_concept_ids << order.drug_order.drug.concept_id
      if (order.drug_order.amount_needed > 0)
        dispense_finish = false
      end
    end

    return unless dispense_finish
    return if dispensed_drugs_concept_ids.blank?

    regimen_id = ActiveRecord::Base.connection.select_value <<EOF
SELECT concept_id FROM drug_ingredient 
WHERE ingredient_id IN (SELECT distinct ingredient_id 
FROM drug_ingredient 
WHERE concept_id IN (#{dispensed_drugs_concept_ids.join(',')}))
GROUP BY concept_id
HAVING COUNT(*) = (SELECT COUNT(distinct ingredient_id) 
FROM drug_ingredient 
WHERE concept_id IN (#{dispensed_drugs_concept_ids.join(',')}))
EOF
  
    regimen_prescribed = regimen_id.to_i rescue ConceptName.find_by_name('UNKNOWN ANTIRETROVIRAL DRUG').concept_id
    
    if (Observation.find(:first,:conditions => ["person_id = ? AND encounter_id = ? AND concept_id = ?",
            self.id,encounter.id,ConceptName.find_by_name('ARV REGIMENS RECEIVED ABSTRACTED CONSTRUCT').concept_id])).blank?
      regimen_value_text = Concept.find(regimen_prescribed).shortname
      regimen_value_text = ConceptName.find_by_concept_id(regimen_prescribed).name if regimen_value_text.blank?
      obs = Observation.new(
        :concept_name => "ARV REGIMENS RECEIVED ABSTRACTED CONSTRUCT",
        :person_id => self.id,
        :encounter_id => encounter.id,
        :value_text => regimen_value_text,
        :value_coded => regimen_prescribed,
        :obs_datetime => encounter.encounter_datetime)
      obs.save
      return obs.value_text 
    end
  end

  def gender
    self.person.sex
  end

  def last_art_visit_before(date = Date.today)
    art_encounters = ['ART_INITIAL','HIV RECEPTION','VITALS','HIV STAGING','ART VISIT','ART ADHERENCE','TREATMENT','DISPENSING']
    art_encounter_type_ids = EncounterType.find(:all,:conditions => ["name IN (?)",art_encounters]).map{|e|e.encounter_type_id}
    Encounter.find(:first,
      :conditions => ["DATE(encounter_datetime) < ? AND patient_id = ? AND encounter_type IN (?)",date,
        self.id,art_encounter_type_ids],
      :order => 'encounter_datetime DESC').encounter_datetime.to_date rescue nil
  end
  
  def drug_given_before(date = Date.today)
    encounter_type = EncounterType.find_by_name('TREATMENT')
    Encounter.find(:first,
      :joins => 'INNER JOIN orders ON orders.encounter_id = encounter.encounter_id
               INNER JOIN drug_order ON orders.order_id = orders.order_id', 
      :conditions => ["quantity IS NOT NULL AND encounter_type = ? AND
               encounter.patient_id = ? AND DATE(encounter_datetime) < ?",
        encounter_type.id,self.id,date.to_date],:order => 'encounter_datetime DESC').orders rescue []
  end

  def prescribe_arv_this_visit(date = Date.today)
    encounter_type = EncounterType.find_by_name('ART VISIT')
    yes_concept = ConceptName.find_by_name('YES').concept_id
    refer_concept = ConceptName.find_by_name('PRESCRIBE ARVS THIS VISIT').concept_id
    refer_patient = Encounter.find(:first,
      :joins => 'INNER JOIN obs USING (encounter_id)',
      :conditions => ["encounter_type = ? AND concept_id = ? AND person_id = ? AND value_coded = ? AND DATE(obs_datetime) = ?",
        encounter_type.id,refer_concept,self.id,yes_concept,date.to_date],:order => 'encounter_datetime DESC')
    return false if refer_patient.blank?
    return true
  end

  def number_of_days_to_add_to_next_appointment_date(date = Date.today)
    #because a dispension/pill count can have several drugs,we pick the drug with the lowest pill count
    #and we also make sure the drugs in the pill count/Adherence encounter are the same as the one in Dispension encounter
    
    concept_id = ConceptName.find_by_name('AMOUNT OF DRUG BROUGHT TO CLINIC').concept_id
    encounter_type = EncounterType.find_by_name('ART ADHERENCE')
    adherence = Observation.find(:all,
      :joins => 'INNER JOIN encounter USING(encounter_id)',
      :conditions =>["encounter_type = ? AND patient_id = ? AND concept_id = ? AND DATE(encounter_datetime)=?",
        encounter_type.id,self.id,concept_id,date.to_date],:order => 'encounter_datetime DESC')
    return 0 if adherence.blank?
    concept_id = ConceptName.find_by_name('AMOUNT DISPENSED').concept_id
    encounter_type = EncounterType.find_by_name('DISPENSING')
    drug_dispensed = Observation.find(:all,
      :joins => 'INNER JOIN encounter USING(encounter_id)',
      :conditions =>["encounter_type = ? AND patient_id = ? AND concept_id = ? AND DATE(encounter_datetime)=?",
        encounter_type.id,self.id,concept_id,date.to_date],:order => 'encounter_datetime DESC')

    #check if what was dispensed is what was counted as remaing pills
    return 0 unless (drug_dispensed.map{| d | d.value_drug } - adherence.map{|a|a.order.drug_order.drug_inventory_id}) == []
   
    #the folliwing block of code picks the drug with the lowest pill count
    count_drug_count = []
    (adherence).each do | adh |
      unless count_drug_count.blank?
        if adh.value_numeric < count_drug_count[1]
          count_drug_count = [adh.order.drug_order.drug_inventory_id,adh.value_numeric]
        end
      end
      count_drug_count = [adh.order.drug_order.drug_inventory_id,adh.value_numeric] if count_drug_count.blank?
    end

    #from the drug dispensed on that day,we pick the drug "plus it's daily dose" that match the drug with the lowest pill count    
    equivalent_daily_dose = 1
    (drug_dispensed).each do | dispensed_drug |
      drug_order = dispensed_drug.order.drug_order
      if count_drug_count[0] == drug_order.drug_inventory_id
        equivalent_daily_dose = drug_order.equivalent_daily_dose
      end
    end
    (count_drug_count[1] / equivalent_daily_dose).to_i
  end

  def art_start_date
    date = ActiveRecord::Base.connection.select_value <<EOF
SELECT patient_start_date(#{self.id})
EOF
    return date.to_date rescue nil
  end

  def art_patient?
    program_id = Program.find_by_name('HIV PROGRAM').id
    enrolled = PatientProgram.find(:first,:conditions =>["program_id = ? AND patient_id = ?",program_id,self.id]).blank?
    return true unless enrolled 
    false
  end

  def self.art_info_for_remote(national_id)

    patient = Person.search_by_identifier(national_id).first.patient rescue []
    return {} if patient.blank?

    results = {}
    result_hash = {}
    
    if patient.art_patient?
      clinic_encounters = ["APPOINTMENT","ART VISIT","VITALS","HIV STAGING",'ART ADHERENCE','DISPENSING','ART_INITIAL']
      clinic_encounter_ids = EncounterType.find(:all,:conditions => ["name IN (?)",clinic_encounters]).collect{| e | e.id }
      first_encounter_date = patient.encounters.find(:first, 
        :order => 'encounter_datetime',
        :conditions => ['encounter_type IN (?)',clinic_encounter_ids]).encounter_datetime.strftime("%d-%b-%Y") rescue 'Uknown'

      last_encounter_date = patient.encounters.find(:first, 
        :order => 'encounter_datetime DESC',
        :conditions => ['encounter_type IN (?)',clinic_encounter_ids]).encounter_datetime.strftime("%d-%b-%Y") rescue 'Uknown'
      

      art_start_date = patient.art_start_date.strftime("%d-%b-%Y") rescue 'Uknown'
      last_given_drugs = patient.person.observations.recent(1).question("ARV REGIMENS RECEIVED ABSTRACTED CONSTRUCT").last rescue nil
      last_given_drugs = last_given_drugs.value_text rescue 'Uknown'

      program_id = Program.find_by_name('HIV PROGRAM').id
      outcome = PatientProgram.find(:first,:conditions =>["program_id = ? AND patient_id = ?",program_id,patient.id],:order => "date_enrolled DESC")
      art_clinic_outcome = outcome.patient_states.last.program_workflow_state.concept.fullname rescue 'Unknown'

      date_tested_positive = patient.person.observations.recent(1).question("FIRST POSITIVE HIV TEST DATE").last rescue nil
      date_tested_positive = date_tested_positive.to_s.split(':')[1].strip.to_date.strftime("%d-%b-%Y") rescue 'Uknown'
      
      cd4_info = patient.person.observations.recent(1).question("CD4 COUNT").all rescue []
      cd4_data_and_date_hash = {}

      (cd4_info || []).map do | obs |
        cd4_data_and_date_hash[obs.obs_datetime.to_date.strftime("%d-%b-%Y")] = obs.value_numeric
      end

      result_hash = {
        'art_start_date' => art_start_date,
        'date_tested_positive' => date_tested_positive,
        'first_visit_date' => first_encounter_date,
        'last_visit_date' => last_encounter_date,
        'cd4_data' => cd4_data_and_date_hash,
        'last_given_drugs' => last_given_drugs,
        'art_clinic_outcome' => art_clinic_outcome,
        'arv_number' => patient.arv_number
      }
    end

    results["person"] = result_hash
    return results
  end

  def set_new_filing_number
    ActiveRecord::Base.transaction do
      global_property_value = GlobalProperty.find_by_property("filing.number.limit").property_value rescue '10'

      filing_number_identifier_type = PatientIdentifierType.find_by_name("Filing number")
      archive_identifier_type = PatientIdentifierType.find_by_name("Archived filing number")

      next_filing_number = PatientIdentifier.next_filing_number('Filing number')
      if (next_filing_number[5..-1].to_i >= global_property_value.to_i)
        encounter_type_name = ['REGISTRATION','VITALS','ART_INITIAL','ART VISIT',
          'TREATMENT','HIV RECEPTION','HIV STAGING','DISPENSING','APPOINTMENT']
        encounter_type_ids = EncounterType.find(:all,:conditions => ["name IN (?)",encounter_type_name]).map{|n|n.id} 
    
        all_filing_numbers = PatientIdentifier.find(:all, :conditions =>["identifier_type = ?",
            filing_number_identifier_type.id],:group=>"patient_id")
        patient_ids = all_filing_numbers.collect{|i|i.patient_id}
        patient_to_be_archived = Encounter.find_by_sql(["
          SELECT patient_id, MAX(encounter_datetime) AS last_encounter_id
          FROM encounter 
          WHERE patient_id IN (?)
          AND encounter_type IN (?) 
          GROUP BY patient_id
          ORDER BY last_encounter_id
          LIMIT 1",patient_ids,encounter_type_ids]).first.patient rescue nil

        if patient_to_be_archived.blank?
          patient_to_be_archived = PatientIdentifier.find(:last,:conditions =>["identifier_type = ?",
              filing_number_identifier_type.id],
            :group=>"patient_id",:order => "identifier DESC").patient rescue nil
        end
      end

      if self.get_identifier('Archived filing number')
        #voids the record- if patient has a dormant filing number
        current_archive_filing_numbers = self.patient_identifiers.collect{|identifier|
          identifier if identifier.identifier_type == archive_identifier_type.id and identifier.voided
        }.compact
        current_archive_filing_numbers.each do | filing_number |
          filing_number.voided = 1
          filing_number.void_reason = "patient assign new active filing number"
          filing_number.voided_by = User.current_user.id
          filing_number.date_voided = Time.now()
          filing_number.save
        end
      end
     
      unless patient_to_be_archived.blank?
        filing_number = PatientIdentifier.new()
        filing_number.patient_id = self.id
        filing_number.identifier = patient_to_be_archived.get_identifier('Filing Number')
        filing_number.identifier_type = filing_number_identifier_type.id
        filing_number.save

        current_active_filing_numbers = patient_to_be_archived.patient_identifiers.collect{|identifier|
          identifier if identifier.identifier_type == filing_number_identifier_type.id and not identifier.voided
        }.compact
        current_active_filing_numbers.each do | filing_number |
          filing_number.voided = 1
          filing_number.void_reason = "Archived - filing number given to:#{self.id}"
          filing_number.voided_by = User.current_user.id
          filing_number.date_voided = Time.now()
          filing_number.save
        end
      else
        filing_number = PatientIdentifier.new()
        filing_number.patient_id = self.id
        filing_number.identifier = next_filing_number
        filing_number.identifier_type = filing_number_identifier_type.id
        filing_number.save
      end 
      true
    end
  end

  def set_filing_number
    next_filing_number = PatientIdentifier.next_filing_number # gets the new filing number! 
    # checks if the the new filing number has passed the filing number limit...
    # move dormant patient from active to dormant filing area ... if needed
    Patient.next_filing_number_to_be_archived(self,next_filing_number) 
  end 

  def self.next_filing_number_to_be_archived(current_patient , next_filing_number)
    ActiveRecord::Base.transaction do
      global_property_value = GlobalProperty.find_by_property("filing.number.limit").property_value rescue '10000'
      active_filing_number_identifier_type = PatientIdentifierType.find_by_name("Filing Number")
      dormant_filing_number_identifier_type = PatientIdentifierType.find_by_name('Archived filing number')

      if (next_filing_number[5..-1].to_i >= global_property_value.to_i)
        encounter_type_name = ['REGISTRATION','VITALS','ART_INITIAL','ART VISIT',
          'TREATMENT','HIV RECEPTION','HIV STAGING','DISPENSING','APPOINTMENT']
        encounter_type_ids = EncounterType.find(:all,:conditions => ["name IN (?)",encounter_type_name]).map{|n|n.id} 
      
        all_filing_numbers = PatientIdentifier.find(:all, :conditions =>["identifier_type = ?",
            PatientIdentifierType.find_by_name("Filing Number").id],:group=>"patient_id")
        patient_ids = all_filing_numbers.collect{|i|i.patient_id}
        patient_to_be_archived = Encounter.find_by_sql(["
          SELECT patient_id, MAX(encounter_datetime) AS last_encounter_id
          FROM encounter 
          WHERE patient_id IN (?)
          AND encounter_type IN (?) 
          GROUP BY patient_id
          ORDER BY last_encounter_id
          LIMIT 1",patient_ids,encounter_type_ids]).first.patient rescue nil
        if patient_to_be_archived.blank?
          patient_to_be_archived = PatientIdentifier.find(:last,:conditions =>["identifier_type = ?",
              PatientIdentifierType.find_by_name("Filing Number").id],
            :group=>"patient_id",:order => "identifier DESC").patient rescue nil
        end
      end

      if patient_to_be_archived
        filing_number = PatientIdentifier.new()
        filing_number.patient_id = patient_to_be_archived.id
        filing_number.identifier_type = dormant_filing_number_identifier_type.id
        filing_number.identifier = PatientIdentifier.next_filing_number("Archived filing number")
        filing_number.save
       
        #assigning "patient_to_be_archived" filing number to the new patient
        filing_number= PatientIdentifier.new()
        filing_number.patient_id = current_patient.id
        filing_number.identifier_type = active_filing_number_identifier_type.id
        filing_number.identifier = patient_to_be_archived.get_identifier('Filing Number')
        filing_number.save

        #void current filing number
        current_filing_numbers =  PatientIdentifier.find(:all,:conditions=>["patient_id=? AND identifier_type = ?",
            patient_to_be_archived.id,PatientIdentifierType.find_by_name("Filing Number").id])
        current_filing_numbers.each do | filing_number |
          filing_number.voided = 1
          filing_number.voided_by = User.current_user.id
          filing_number.void_reason = "Archived - filing number given to:#{current_patient.id}"
          filing_number.date_voided = Time.now()
          filing_number.save
        end
      else
        filing_number = PatientIdentifier.new()
        filing_number.patient_id = current_patient.id
        filing_number.identifier_type = active_filing_number_identifier_type.id
        filing_number.identifier = next_filing_number
        filing_number.save
      end
    end

    true
  end

  def patient_to_be_archived
    active_identifier_type = PatientIdentifierType.find_by_name("Filing Number")
    PatientIdentifier.find_by_sql(["
      SELECT * FROM patient_identifier 
      WHERE voided = 1 AND identifier_type = ? AND void_reason = ? ORDER BY date_created DESC",
        active_identifier_type.id,"Archived - filing number given to:#{self.id}"]).first.patient rescue nil
  end

  def old_filing_number(type = 'Filing Number')
    identifier_type = PatientIdentifierType.find_by_name(type)
    PatientIdentifier.find_by_sql(["
      SELECT * FROM patient_identifier 
      WHERE patient_id = ?
      AND identifier_type = ? 
      AND voided = 1
      ORDER BY date_created DESC
      LIMIT 1",self.id,identifier_type.id]).first.identifier rescue nil
  end

  def self.printing_filing_number_label(number=nil)
    return number[5..5] + " " + number[6..7] + " " + number[8..-1] unless number.nil?
  end

  def self.printing_message(new_patient , archived_patient , creating_new_filing_number_for_patient = false)
    arv_code = Location.current_arv_code
    new_patient_name = new_patient.name
    new_filing_number = self.printing_filing_number_label(new_patient.get_identifier('Filing Number'))
    old_archive_filing_number = self.printing_filing_number_label(new_patient.old_filing_number('Archived filing number'))
    unless archived_patient.blank?
      old_active_filing_number = self.printing_filing_number_label(archived_patient.old_filing_number)
      new_archive_filing_number = self.printing_filing_number_label(archived_patient.get_identifier('Archived filing number'))
    end

    if new_patient and archived_patient and creating_new_filing_number_for_patient
      table = <<EOF
<div id='patients_info_div'>
<table id = 'filing_info'>
<tr>
  <th class='filing_instraction'>Filing actions required</th>
  <th class='filing_instraction'>Name</th>
  <th style="text-align:left;">Old label</th>
  <th style="text-align:left;">New label</th>
</tr>

<tr>
  <td style='text-align:left;'>Active → Dormant</td>
  <td class = 'filing_instraction'>#{archived_patient.name}</td>
  <td class = 'old_label'>#{old_active_filing_number}</td>
  <td class='new_label'>#{new_archive_filing_number}</td>
</tr>

<tr>
  <td style='text-align:left;'>Add → Active</td>
  <td class = 'filing_instraction'>#{new_patient_name}</td>
  <td class = 'old_label'>#{old_archive_filing_number}</td>
  <td class='new_label'>#{new_filing_number}</td>
</tr>
</table>
</div>
EOF
    elsif new_patient and creating_new_filing_number_for_patient
      table = <<EOF
<div id='patients_info_div'>
<table id = 'filing_info'>
<tr>
  <th class='filing_instraction'>Filing actions required</th>
  <th class='filing_instraction'>Name</th>
  <th>&nbsp;</th>
  <th style="text-align:left;">New label</th>
</tr>

<tr>
  <td style='text-align:left;'>Add → Active</td>
  <td class = 'filing_instraction'>#{new_patient_name}</td>
  <td class = 'filing_instraction'>&nbsp;</td>
  <td class='new_label'>#{new_filing_number}</td>
</tr>
</table>
</div>
EOF
    elsif new_patient and archived_patient and not creating_new_filing_number_for_patient
      table = <<EOF
<div id='patients_info_div'>
<table id = 'filing_info'>
<tr>
  <th class='filing_instraction'>Filing actions required</th>
  <th class='filing_instraction'>Name</th>
  <th style="text-align:left;">Old label</th>
  <th style="text-align:left;">New label</th>
</tr>

<tr>
  <td style='text-align:left;'>Active → Dormant</td>
  <td class = 'filing_instraction'>#{archived_patient.name}</td>
  <td class = 'old_label'>#{old_active_filing_number}</td>
  <td class='new_label'>#{new_archive_filing_number}</td>
</tr>

<tr>
  <td style='text-align:left;'>Add → Active</td>
  <td class = 'filing_instraction'>#{new_patient_name}</td>
  <td class = 'old_label'>#{old_archive_filing_number}</td>
  <td class='new_label'>#{new_filing_number}</td>
</tr>
</table>
</div>
EOF
    elsif new_patient and not creating_new_filing_number_for_patient
      table = <<EOF
<div id='patients_info_div'>
<table id = 'filing_info'>
<tr>
  <th class='filing_instraction'>Filing actions required</th>
  <th class='filing_instraction'>Name</th>
  <th>Old label</th>
  <th style="text-align:left;">New label</th>
</tr>

<tr>
  <td style='text-align:left;'>Add → Active</td>
  <td class = 'filing_instraction'>#{new_patient_name}</td>
  <td class = 'old_label'>#{old_archive_filing_number}</td>
  <td class='new_label'>#{new_filing_number}</td>
</tr>
</table>
</div>
EOF
    end


    return table
  end   

  def id_identifiers
    identifier_type = ["Legacy Pediatric id","National id","Legacy National id"]
    identifier_types = PatientIdentifierType.find(:all,
      :conditions=>["name IN (?)",identifier_type]
    ).collect{| type |type.id }
    
    PatientIdentifier.find(:all,
      :conditions=>["patient_id=? AND identifier_type IN (?)",
        self.id,identifier_types]).collect{| i | i.identifier }
  end

  def self.edit_mastercard_attribute(attribute_name)
    edit_page = attribute_name
  end

  def self.save_mastercard_attribute(params)
    patient = Patient.find(params[:patient_id])
    case params[:field]
    when 'arv_number'
      type = params['identifiers'][0][:identifier_type]
      #patient = Patient.find(params[:patient_id])
      patient_identifiers = PatientIdentifier.find(:all,
        :conditions => ["voided = 0 AND identifier_type = ? AND patient_id = ?",type.to_i,patient.id])

      patient_identifiers.map{|identifier|
        identifier.voided = 1
        identifier.void_reason = "given another number"
        identifier.date_voided  = Time.now()
        identifier.voided_by = User.current_user.id
        identifier.save
      }

      identifier = params['identifiers'][0][:identifier].strip
      if identifier.match(/(.*)[A-Z]/i).blank?
        params['identifiers'][0][:identifier] = "#{PatientIdentifier.site_prefix} #{identifier}"
      end
      patient.patient_identifiers.create(params[:identifiers])
    when "name"
      names_params =  {"given_name" => params[:given_name].to_s,"family_name" => params[:family_name].to_s}
      patient.person.names.first.update_attributes(names_params) if names_params
    when "age"
      birthday_params = params[:person]

      if !birthday_params.empty?
        if birthday_params["birth_year"] == "Unknown"
          patient.person.set_birthdate_by_age(birthday_params["age_estimate"])
        else
          patient.person.set_birthdate(birthday_params["birth_year"], birthday_params["birth_month"], birthday_params["birth_day"])
        end
        patient.person.birthdate_estimated = 1 if params["birthdate_estimated"] == 'true'
        patient.person.save
      end
    when "sex"
      gender ={"gender" => params[:gender].to_s}
      patient.person.update_attributes(gender) if !gender.empty?
    when "location"
      location = params[:person][:addresses]
      patient.person.addresses.first.update_attributes(location) if location
    when "occupation"
      attribute = params[:person][:attributes]
      occupation_attribute = PersonAttributeType.find_by_name("Occupation")
      exists_person_attribute = PersonAttribute.find(:first, :conditions => ["person_id = ? AND person_attribute_type_id = ?", patient.person.id, occupation_attribute.person_attribute_type_id]) rescue nil
      if exists_person_attribute
        exists_person_attribute.update_attributes({'value' => attribute[:occupation].to_s})
      end
    when "guardian"
      names_params =  {"given_name" => params[:given_name].to_s,"family_name" => params[:family_name].to_s}
      Person.find(params[:guardian_id].to_s).names.first.update_attributes(names_params) rescue '' if names_params
    when "address"
      address2 = params[:person][:addresses]
      patient.person.addresses.first.update_attributes(address2) if address2
    when "ta"
      county_district = params[:person][:addresses]
      patient.person.addresses.first.update_attributes(county_district) if county_district
    end
  end

  def eid_number
    eid_number_id = PatientIdentifierType.find_by_name('EID Number').patient_identifier_type_id
    PatientIdentifier.identifier(self.patient_id, eid_number_id).identifier rescue nil
  end

  def pre_art_number
    pre_art_number_id = PatientIdentifierType.find_by_name('Pre ART Number (Old format)').patient_identifier_type_id
    PatientIdentifier.identifier(self.patient_id, pre_art_number_id).identifier rescue nil
  end

  def traditional_authority
    self.person.demographics['person']['addresses']['county_district'].to_s
  end
  
  def appointment_dates(start_date, end_date = nil)

    end_date = start_date if end_date.nil?

    appointment_date_concept_id = Concept.find_by_name("APPOINTMENT DATE").concept_id rescue nil

    appointments = Observation.find(:all,
      :conditions => ["DATE(obs.value_datetime) >= ? AND DATE(obs.value_datetime) <= ? AND " +
          "obs.concept_id = ? AND obs.voided = 0 AND obs.person_id = ?", start_date.to_date,
        end_date.to_date, appointment_date_concept_id, self.id])

    appointments
  end

  def reason_for_art_eligibility
    reasons = self.person.observations.recent(1).question("REASON FOR ART ELIGIBILITY").all rescue nil
    reasons.map{|c|ConceptName.find(c.value_coded_name_id).name}.join(',') rescue nil
  end

  def child_bearing_female?
    (gender == "Female" && self.person.age >= 9 && self.person.age <= 45) ? true : false
  end
  #pb: bug-2677 Added the block below to check if the patient was transfered in
  def transfer_in?
    patient_transfer_in = self.person.observations.recent(1).question("HAS TRANSFER LETTER").all rescue nil
    return false if patient_transfer_in.blank?
    return true
  end

  def transfer_in_date?
    patient_transfer_in = self.person.observations.recent(1).question("HAS TRANSFER LETTER").all rescue nil
    return patient_transfer_in.each{|datetime| return datetime.obs_datetime  if datetime.obs_datetime}
  end
  
  #from TB ART TO BART
  
  def tb_status
    Concept.find(Observation.find(:last, :conditions => ["person_id = ? AND concept_id = ?", self.id, ConceptName.find_by_name("TB STATUS").concept_id]).value_coded).concept_names.map{|c|c.name}[0] rescue "UNKNOWN"
  end
  
  def hiv_status
    status = Concept.find(Observation.find(:last, :conditions => ["person_id = ? AND concept_id = ?", self.id, ConceptName.find_by_name("HIV STATUS").concept_id]).value_coded).concept_names.map{|c|c.name}[0] rescue "UNKNOWN"
    if status.upcase == 'UNKNOWN'
      return self.patient_programs.collect{|p|p.program.name}.include?('HIV PROGRAM') ? 'Positive' : status
    end
    return status
  end

  def hiv_test_date
    test_date = Observation.find(:last, :conditions => ["person_id = ? AND concept_id = ?", self.id, ConceptName.find_by_name("HIV test date").concept_id]).value_datetime rescue nil
    return test_date
  end
  
  def months_since_last_hiv_test
    today = Date.today
    hiv_test_date = self.hiv_test_date
    months = (today.year * 12 + today.month) - (hiv_test_date.year * 12 + hiv_test_date.month) rescue nil
    return months
  end
  
  def tb_patient?
    return self.given_tb_medication_before?
  end
  
  def given_tb_medication_before?
    self.orders.each{|order|
      drug_order = order.drug_order
      drug_order_quantity = drug_order.quantity
      if drug_order_quantity == nil
        drug_order_quantity = 0
      end
      next if drug_order == nil
      next unless drug_order_quantity > 0
      return true if drug_order.drug.tb_medication?
    }
    false
  end
  
  def recent_sputum_orders
    sputum_concept_names = ["AAFB(1st)", "AAFB(2nd)", "AAFB(3rd)", "Culture(1st)", "Culture(2nd)"]
    sputum_concept_ids = ConceptName.find(:all, :conditions => ["name IN (?)", sputum_concept_names]).map(&:concept_id)
    Observation.find(:all, :conditions => ["person_id = ? AND concept_id = ? AND (value_coded in (?) OR value_text in (?))", self.id, ConceptName.find_by_name('Tests ordered').concept_id, sputum_concept_ids, sputum_concept_names], :order => "obs_datetime desc", :limit => 3)
  end

  def sputum_orders_without_submission
    self.recent_sputum_orders.collect{|order| order unless Observation.find(:all, :conditions => ["person_id = ? AND concept_id = ?", self.id, Concept.find_by_name("Sputum submission")]).map{|o| o.accession_number}.include?(order.accession_number)}.compact rescue []
  end

  def sputum_submissons_with_no_results
    sputum_concept_names = ["AAFB(1st)", "AAFB(2nd)", "AAFB(3rd)", "Culture(1st)", "Culture(2nd)"]
    sputum_concept_ids = ConceptName.find(:all, :conditions => ["name IN (?)", sputum_concept_names]).map(&:concept_id)
    sputums_array = Observation.find(:all, :conditions => ["person_id = ? AND concept_id = ? AND (value_coded in (?) OR value_text in (?))", self.id, ConceptName.find_by_name('Tests ordered').concept_id, sputum_concept_ids, sputum_concept_names], :order => "obs_datetime desc", :limit => 3)

    results_concept_name = ["AAFB(1st) results", "AAFB(2nd) results", "AAFB(3rd) results", "Culture(1st) Results", "Culture-2 Results"]
    sputum_results_id = ConceptName.find(:all, :conditions => ["name IN (?)", results_concept_name ]).map(&:concept_id)

    sputums_array = sputums_array.select { |order|
                       accessor_history = Observation.find(:all, :conditions => ["person_id = ? AND accession_number  = (?) AND voided = 0 AND concept_id IN (?)",  self.id, order.accession_number, sputum_results_id]);
                       accessor_history.size == 0
                    }
    sputums_array
  end

  def recent_sputum_submissions
    sputum_concept_names = ["AAFB(1st)", "AAFB(2nd)", "AAFB(3rd)", "Culture(1st)", "Culture(2nd)"]
    sputum_concept_ids = ConceptName.find(:all, :conditions => ["name IN (?)", sputum_concept_names]).map(&:concept_id)
    Observation.find(:all, :conditions => ["person_id = ? AND concept_id = ? AND (value_coded in (?) OR value_text in (?))", self.id, ConceptName.find_by_name('Sputum submission').concept_id, sputum_concept_ids, sputum_concept_names], :order => "obs_datetime desc", :limit => 3)
  end

  def sputum_submissions_waiting_for_results
    sputum_concept_names = ["AAFB(1st) results", "AAFB(2nd) results", "AAFB(3rd) results", "Culture(1st) Results", "Culture-2 Results"]
    sputum_concept_ids = ConceptName.find(:all, :conditions => ["name IN (?)", sputum_concept_names]).map(&:concept_id)

   Encounter.find(:last,:conditions =>["encounter_type = ? and patient_id = ?",
        EncounterType.find_by_name("LAB RESULTS").id,self.id]).observations.map{|o| o if sputum_concept_ids.include?(o.concept_id)}.join' ' rescue []
  end

  def is_first_visit?
    clinic_encounters = ["APPOINTMENT","ART VISIT","VITALS","HIV STAGING",
                          'ART ADHERENCE','DISPENSING','ART_INITIAL', "LAB ORDERS",
                          "LAB RESULTS","HIV RECEPTION","SPUTUM SUBMISSION",
                          "TB RECEPTION","TB REGISTRATION","TB TREATMENT",
                          "TB_FOLLOWUP"
                          ]
    current_date = Time.now.strftime("%d-%b-%Y")

    clinic_encounter_ids = EncounterType.find(:all,:conditions => ["name IN (?)",clinic_encounters]).collect{| e | e.id }
    first_encounter_date = self.encounters.find(:first,
      :order => 'encounter_datetime',
      :conditions => ['encounter_type IN (?)',clinic_encounter_ids]).encounter_datetime.strftime("%d-%b-%Y") rescue 'Unknown'

    return true if first_encounter_date == 'Unknown'
    return true if current_date == first_encounter_date
    return false if current_date > first_encounter_date

  end

  def recent_lab_orders_label(test_list)
    lab_orders = test_list
    labels = []
    i = 0
    lab_orders.each{|test|
      observation = Observation.find(test.to_i)

      accession_number = "#{observation.accession_number rescue nil}"

        if accession_number != ""
          label = 'label' + i.to_s
          label = ZebraPrinter::StandardLabel.new
          label.font_size = 2
          label.font_horizontal_multiplier = 2
          label.font_vertical_multiplier = 2
          label.left_margin = 50
          label.draw_barcode(50,180,0,1,5,15,120,false,"#{accession_number}")
          label.draw_multi_text("#{self.person.name.titleize.delete("'")} #{self.national_id_with_dashes}")
          label.draw_multi_text("#{observation.name rescue nil}")
          label.draw_multi_text("#{accession_number rescue nil}")
          label.draw_multi_text("#{observation.date_created.strftime("%d-%b-%Y %H:%M")}")
          labels << label
         end

         i = i + 1
    }

      print_labels = []
      label = 0
      while label <= labels.size
        print_labels << labels[label].print(1) if labels[label] != nil
        label = label + 1
      end

      return print_labels
  end

  def get_recent_lab_orders_label
    encounters = Encounter.find(:all,:conditions =>["encounter_type = ? and patient_id = ?",
        EncounterType.find_by_name("LAB ORDERS").id,self.id]).last(5)
      observations = []

    encounters.each{|encounter|
      encounter.observations.each{|observation|
       unless observation['concept_id'] == Concept.find_by_name("Workstation location").concept_id
          observations << ["#{ConceptName.find_by_concept_id(observation['value_coded'].to_i).name} : #{observation['date_created'].strftime("%Y-%m-%d") }",
                            "#{observation['obs_id']}"]
       end
      }
    }
    return observations
  end

	def residence
		patient = Person.find(self.id)
		return patient.address
	end
  
	def age
		patient = Person.find(self.id)
		return patient.age
	end  
end
