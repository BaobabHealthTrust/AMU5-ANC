class Mastercard 

 attr_accessor :date, :weight, :height, :bmi, :outcome, :reg, :s_eff, :sk , :pn, :hp, :pills, :gave, 
   :cpt, :cd4,:estimated_date,:next_app, :tb_status, :doses_missed, :visit_by, :date_of_outcome,
   :reg_type, :adherence, :patient_visits, :sputum_count, :end_date, :art_status, :encounter_id , :notes, :appointment_date

 attr_accessor :patient_id,:arv_number, :national_id ,:name ,:age ,:sex, :init_wt, :init_ht ,
   :init_bmi ,:transfer_in ,:address, :landmark, :occupation, :guardian, :agrees_to_followup,
   :hiv_test_location, :hiv_test_date, :reason_for_art_eligibility, :date_of_first_line_regimen ,
   :tb_within_last_two_yrs, :eptb ,:ks,:pulmonary_tb, :first_line_drugs, :alt_first_line_drugs,
   :second_line_drugs, :date_of_first_alt_line_regimen, :date_of_second_line_regimen, :transfer_in_date,
   :cd4_count_date, :cd4_count, :pregnant, :who_clinical_conditions, :tlc, :tlc_date, :tb_status_at_initiation,
   :ever_received_art, :last_art_drugs_taken, :last_art_drugs_date_taken,
   :first_positive_hiv_test_site, :first_positive_hiv_test_date, :first_positive_hiv_test_arv_number,
   :first_positive_hiv_test_type, :months_on_art

  def self.demographics(patient_obj)
    visits = self.new()
    person_demographics = patient_obj.person.demographics
    visits.patient_id = patient_obj.id
    visits.arv_number = patient_obj.get_identifier('ARV Number')
    visits.address = person_demographics['person']['addresses']['city_village']
    visits.national_id = person_demographics['person']['patient']['identifiers']['National id']
    visits.name = person_demographics['person']['names']['given_name'] + ' ' + person_demographics['person']['names']['family_name'] rescue nil
    visits.sex = person_demographics['person']['gender']
    visits.age =patient_obj.person.age
    visits.occupation = person_demographics['person']['attributes']['occupation']
    visits.address = person_demographics['person']['addresses']['city_village']
    visits.landmark = person_demographics['person']['addresses']['address1']
    visits.init_wt = patient_obj.initial_weight
    visits.init_ht = patient_obj.initial_height
    visits.bmi = patient_obj.initial_bmi
    visits.agrees_to_followup = patient_obj.person.observations.recent(1).question("Agrees to followup").all rescue nil
    visits.agrees_to_followup = visits.agrees_to_followup.to_s.split(':')[1].strip rescue nil
    visits.hiv_test_date = patient_obj.person.observations.recent(1).question("Confirmatory HIV test date").all rescue nil
    visits.hiv_test_date = visits.hiv_test_date.to_s.split(':')[1].strip rescue nil
    visits.hiv_test_location = patient_obj.person.observations.recent(1).question("Confirmatory HIV test location").all rescue nil
    visits.hiv_test_location = visits.hiv_test_location.to_s.split(':')[1].strip rescue nil
    visits.guardian = patient_obj.person.relationships.map{|r|Person.find(r.person_b).name}.join(' : ') rescue 'NONE'
    visits.reason_for_art_eligibility = patient_obj.reason_for_art_eligibility
    visits.transfer_in = patient_obj.transfer_in? #pb: bug-2677 Made this to use the newly created patient model method 'transfer_in?'
    visits.transfer_in == false ? visits.transfer_in = 'NO' : visits.transfer_in = 'YES'
    
    visits.transfer_in_date = patient_obj.person.observations.recent(1).question("HAS TRANSFER LETTER").all.collect{|o| 
            o.obs_datetime if o.answer_string.strip == "YES"}.last rescue nil

    regimens = {}
    regimen_types = ['FIRST LINE ANTIRETROVIRAL REGIMEN','ALTERNATIVE FIRST LINE ANTIRETROVIRAL REGIMEN','SECOND LINE ANTIRETROVIRAL REGIMEN']
    regimen_types.map do | regimen |
      concept_member_ids = Concept.find_by_name(regimen).concept_members.collect{|c|c.concept_id}
      case regimen
        when 'FIRST LINE ANTIRETROVIRAL REGIMEN'
          regimens[regimen] = concept_member_ids
        when 'ALTERNATIVE FIRST LINE ANTIRETROVIRAL REGIMEN'
          regimens[regimen] = concept_member_ids
        when 'SECOND LINE ANTIRETROVIRAL REGIMEN'
          regimens[regimen] = concept_member_ids
      end
    end

    first_treatment_encounters = []
    encounter_type = EncounterType.find_by_name('TREATMENT').id
    regimens.map do | regimen_type , ids |
      encounter = Encounter.find(:first,
                                 :joins => "INNER JOIN orders ON encounter.encounter_id = orders.encounter_id",
                                 :conditions =>["encounter_type=? AND encounter.patient_id = ? AND concept_id IN (?) 
                                 AND encounter.voided = 0",encounter_type , patient_obj.id , ids ],
                                 :order =>"encounter_datetime")
      first_treatment_encounters << encounter unless encounter.blank?
    end


    visits.first_line_drugs = []
    visits.alt_first_line_drugs = []
    visits.second_line_drugs = []

    first_treatment_encounters.map do | treatment_encounter | 
      treatment_encounter.orders.map{|order|
        if order.drug_order
          drug = Drug.find(order.drug_order.drug_inventory_id) unless order.drug_order.quantity == 0
          drug_concept_id = drug.concept.concept_id
          regimens.map do | regimen_type , concept_ids |
            if regimen_type == 'FIRST LINE ANTIRETROVIRAL REGIMEN' and concept_ids.include?(drug_concept_id)
              visits.date_of_first_line_regimen = treatment_encounter.encounter_datetime.to_date 
              visits.first_line_drugs << drug.concept.shortname
            elsif regimen_type == 'ALTERNATIVE FIRST LINE ANTIRETROVIRAL REGIMEN' and concept_ids.include?(drug_concept_id)
              visits.date_of_first_alt_line_regimen = treatment_encounter.encounter_datetime.to_date
              visits.alt_first_line_drugs << drug.concept.shortname
            elsif regimen_type == 'SECOND LINE ANTIRETROVIRAL REGIMEN' and concept_ids.include?(drug_concept_id)
              visits.date_of_second_line_regimen = treatment_encounter.encounter_datetime.to_date
              visits.second_line_drugs << drug.concept.shortname
=begin
            elsif drug.arv? and regimen_type == 'FIRST LINE ANTIRETROVIRAL REGIMEN'
              visits.first_line_drugs << drug.concept.shortname
            elsif drug.arv? and regimen_type == 'ALTERNATIVE FIRST LINE ANTIRETROVIRAL REGIMEN'
              visits.alt_first_line_drugs << drug.concept.shortname
            elsif drug.arv? and regimen_type == 'SECOND LINE ANTIRETROVIRAL REGIMEN'
              visits.second_line_drugs << drug.concept.shortname
=end
            end
          end
        end
      }.compact
    end

    ans = ["Extrapulmonary tuberculosis (EPTB)","Pulmonary tuberculosis within the last 2 years","Pulmonary tuberculosis","Kaposis sarcoma"]
    staging_ans = patient_obj.person.observations.recent(1).question("WHO STG CRIT").all

    visits.ks = 'Yes' if staging_ans.map{|obs|ConceptName.find(obs.value_coded_name_id).name}.include?(ans[3])
    visits.tb_within_last_two_yrs = 'Yes' if staging_ans.map{|obs|ConceptName.find(obs.value_coded_name_id).name}.include?(ans[1])
    visits.eptb = 'Yes' if staging_ans.map{|obs|ConceptName.find(obs.value_coded_name_id).name}.include?(ans[0])
    visits.pulmonary_tb = 'Yes' if staging_ans.map{|obs|ConceptName.find(obs.value_coded_name_id).name}.include?(ans[2])
=begin

    #visits.arv_number = patient_obj.ARV_national_id
    visits.transfer =  patient_obj.transfer_in? ? "Yes" : "No"
=end

    hiv_staging = Encounter.find(:last,:conditions =>["encounter_type = ? and patient_id = ?",
        EncounterType.find_by_name("HIV Staging").id,patient_obj.id])

    visits.who_clinical_conditions = ""

    (hiv_staging.observations).collect do |obs|
      name = obs.to_s.split(':')[0].strip rescue nil
      next unless name == 'WHO STAGES CRITERIA PRESENT'
      condition = obs.to_s.split(':')[1].strip.humanize rescue nil
      visits.who_clinical_conditions = visits.who_clinical_conditions + (condition) + "; "
    end rescue []
    
    # cd4_count_date cd4_count pregnant who_clinical_conditions

    visits.cd4_count_date = nil ; visits.cd4_count = nil ; visits.pregnant = 'N/A'

    (hiv_staging.observations).map do | obs |
      concept_name = obs.to_s.split(':')[0].strip rescue nil
      next if concept_name.blank?
      case concept_name
      when 'CD4 COUNT DATETIME'
        visits.cd4_count_date = obs.value_datetime.to_date
      when 'CD4 COUNT'
        visits.cd4_count = obs.value_numeric
      when 'IS PATIENT PREGNANT?'
        visits.pregnant = obs.to_s.split(':')[1] rescue nil
      when 'LYMPHOCYTE COUNT'
        visits.tlc = obs.value_numeric
      when 'LYMPHOCYTE COUNT DATETIME'
        visits.tlc_date = obs.value_datetime.to_date
      end
    end rescue []

    visits.tb_status_at_initiation = (!visits.tb_status.nil? ? "Curr" : 
          (!visits.tb_within_last_two_yrs.nil? ? (visits.tb_within_last_two_yrs.upcase == "YES" ? 
              "Last 2yrs" : "Never/ >2yrs") : "Never/ >2yrs"))

    art_initial = Encounter.find(:last,:conditions =>["encounter_type = ? and patient_id = ?",
        EncounterType.find_by_name("ART_INITIAL").id,patient_obj.id])

    (art_initial.observations).map do | obs |
      concept_name = obs.to_s.split(':')[0].strip rescue nil
      next if concept_name.blank?
      case concept_name
      when 'Ever received ART?'
        visits.ever_received_art = obs.to_s.split(':')[1].strip rescue nil
      when 'Last ART drugs taken'
        visits.last_art_drugs_taken = obs.to_s.split(':')[1].strip rescue nil
      when 'Date ART last taken'
        visits.last_art_drugs_date_taken = obs.value_datetime.to_date rescue nil
      when 'Confirmatory HIV test location'
        visits.first_positive_hiv_test_site = obs.to_s.split(':')[1].strip rescue nil
      when 'ART number at previous location'
        visits.first_positive_hiv_test_arv_number = obs.to_s.split(':')[1].strip rescue nil
      when 'Confirmatory HIV test type'
        visits.first_positive_hiv_test_type = obs.to_s.split(':')[1].strip rescue nil
      when 'Confirmatory HIV test date'
        visits.first_positive_hiv_test_date = obs.value_datetime.to_date rescue nil
      end
    end rescue []

    visits
  end

  def self.visits(patient_obj,encounter_date = nil)
    patient_visits = {}
    yes = ConceptName.find_by_name("YES")
    if encounter_date.blank?
      observations = Observation.find(:all,:conditions =>["voided = 0 AND person_id = ?",patient_obj.patient_id],:order =>"obs_datetime")
    else
      observations = Observation.find(:all,
        :conditions =>["voided = 0 AND person_id = ? AND Date(obs_datetime) = ?",
        patient_obj.patient_id,encounter_date.to_date],:order =>"obs_datetime")
    end

    clinic_encounters = ["APPOINTMENT", "HEIGHT","WEIGHT","REGIMEN","TB STATUS","SYMPTOMS",
      "VISIT","BMI","PILLS BROUGHT",'ADHERENCE','NOTES','DRUGS GIVEN']
    clinic_encounters.map do |field|
      gave_hash = Hash.new(0) 
      observations.map do |obs|
         encounter_name = obs.encounter.name rescue []
         next if encounter_name.blank?
         next if encounter_name.match(/REGISTRATION/i)
         #next unless clinic_encounters.include?(encounter_name)
         visit_date = obs.obs_datetime.to_date
         patient_visits[visit_date] = self.new() if patient_visits[visit_date].blank?
         case field
          when 'APPOINTMENT'
            concept_name = obs.concept.fullname rescue nil
            next unless concept_name == 'APPOINTMENT DATE' || concept_name == 'Appointment date'
            patient_visits[visit_date].appointment_date = obs.value_datetime
          when 'HEIGHT'
            concept_name = obs.concept.fullname rescue nil
            next unless concept_name == 'HEIGHT (CM)' || concept_name == 'Height (cm)'
            patient_visits[visit_date].height = obs.value_numeric
          when "WEIGHT"
            concept_name = obs.concept.fullname rescue []
            next unless concept_name == 'WEIGHT (KG)' || concept_name == 'Weight (kg)'
            patient_visits[visit_date].weight = obs.value_numeric
          when "BMI"
            concept_name = obs.concept.fullname rescue []
            next unless concept_name == 'BODY MASS INDEX, MEASURED' || concept_name == 'Body mass index, measured'
            patient_visits[visit_date].bmi = obs.value_numeric
          when "VISIT"
            concept_name = obs.concept.fullname rescue []
            next unless concept_name == 'RESPONSIBLE PERSON PRESENT' or concept_name == 'PATIENT PRESENT FOR CONSULTATION'
            patient_visits[visit_date].visit_by = '' if patient_visits[visit_date].visit_by.blank?
            patient_visits[visit_date].visit_by+= "P" if concept_name == 'PATIENT PRESENT FOR CONSULTATION' and obs.value_coded == yes.concept_id
            patient_visits[visit_date].visit_by+= "G" if concept_name == 'RESPONSIBLE PERSON PRESENT' and !obs.value_text.blank?
          when "TB STATUS"
            concept_name = obs.concept.fullname rescue []
            next unless concept_name == 'TB STATUS' || concept_name == 'TB status'
            status = ConceptName.find(obs.value_coded_name_id).name rescue nil
            patient_visits[visit_date].tb_status = status
            patient_visits[visit_date].tb_status = 'noSup' if status == 'TB NOT SUSPECTED'
            patient_visits[visit_date].tb_status = 'sup' if status == 'TB SUSPECTED'
            patient_visits[visit_date].tb_status = 'noRx' if status == 'CONFIRMED TB NOT ON TREATMENT'
            patient_visits[visit_date].tb_status = 'Rx' if status == 'CONFIRMED TB ON TREATMENT'
          when "DRUGS GIVEN"
            concept_name = obs.concept.fullname rescue []
            next unless concept_name == 'AMOUNT DISPENSED' || concept_name == 'Amount dispensed'
            drug_name = Drug.find(obs.value_drug).name
            if drug_name.match(/Cotrimoxazole/i)
              patient_visits[visit_date].cpt += obs.value_numeric unless patient_visits[visit_date].cpt.blank?
              patient_visits[visit_date].cpt = obs.value_numeric if patient_visits[visit_date].cpt.blank?
            else
              patient_visits[visit_date].gave = [] if patient_visits[visit_date].gave.blank?
              patient_visits[visit_date].gave << [drug_name,obs.value_numeric]
            end
          when "REGIMEN"
            concept_name = obs.concept.fullname rescue []
            next unless concept_name == 'WHAT TYPE OF ANTIRETROVIRAL REGIMEN' || concept_name == 'What type of antiretroviral regimen'
            patient_visits[visit_date].reg =  Concept.find_by_concept_id(obs.value_coded).concept_names.typed("SHORT").first.name
          when "SYMPTOMS"
            concept_name = obs.concept.fullname rescue []
            next unless concept_name == 'SYMPTOM PRESENT' || concept_name == 'Symptom present'
            symptoms = obs.to_s.split(':').map{|sy|sy.strip.capitalize unless sy == 'SYMPTOM PRESENT' || sy == 'Symptom present'}.compact rescue []
            patient_visits[visit_date].s_eff = symptoms.join("<br/>") unless symptoms.blank?
          when "PILLS BROUGHT"
            concept_name = obs.concept.fullname rescue []
            next unless concept_name == 'AMOUNT OF DRUG BROUGHT TO CLINIC' || concept_name == 'Amount of drug brought to clinic'
            patient_visits[visit_date].pills = [] if patient_visits[visit_date].pills.blank?
            patient_visits[visit_date].pills << [Drug.find(obs.order.drug_order.drug_inventory_id).name,obs.value_numeric] rescue []
          when "ADHERENCE"
            concept_name = obs.concept.fullname rescue []
            next unless concept_name == 'WHAT WAS THE PATIENTS ADHERENCE FOR THIS DRUG ORDER' || concept_name == 'What was the patients adherence for this drug order'
            next if obs.value_numeric.blank?
            patient_visits[visit_date].adherence = [] if patient_visits[visit_date].adherence.blank?
            patient_visits[visit_date].adherence << [Drug.find(obs.order.drug_order.drug_inventory_id).name,(obs.value_numeric.to_s + '%')]
          when "NOTES"
            concept_name = obs.concept.fullname.strip rescue []
            next unless concept_name == 'CLINICAL NOTES CONSTRUCT' || concept_name == 'Clinical notes construct'
            patient_visits[visit_date].notes+= '<br/>' + obs.value_text unless patient_visits[visit_date].notes.blank?
            patient_visits[visit_date].notes = obs.value_text if patient_visits[visit_date].notes.blank?
         end
      end
    end

    #patients currents/available states (patients outcome/s)
    program_id = Program.find_by_name('HIV PROGRAM').id
    if encounter_date.blank?
      patient_states = PatientState.find(:all,
                                    :joins => "INNER JOIN patient_program p ON p.patient_program_id = patient_state.patient_program_id",
                                    :conditions =>["patient_state.voided = 0 AND p.voided = 0 AND p.program_id = ? AND p.patient_id = ?",
                                    program_id,patient_obj.patient_id],:order => "patient_state_id ASC")
    else
      patient_states = PatientState.find(:all,
                                    :joins => "INNER JOIN patient_program p ON p.patient_program_id = patient_state.patient_program_id",
                                    :conditions =>["patient_state.voided = 0 AND p.voided = 0 AND p.program_id = ? AND start_date = ? AND p.patient_id =?",
                                    program_id,encounter_date.to_date,patient_obj.patient_id],:order => "patient_state_id ASC")  
    end  


    patient_states.each do |state| 
      visit_date = state.start_date.to_date
      patient_visits[visit_date] = self.new() if patient_visits[visit_date].blank?
      patient_visits[visit_date].outcome = state.program_workflow_state.concept.fullname rescue 'Unknown state'
      patient_visits[visit_date].date_of_outcome = state.start_date
    end

    unless encounter_date.blank? 
      outcome = patient_visits[encounter_date].outcome rescue nil
      if outcome.blank?
        state = PatientState.find(:first,
                                  :joins => "INNER JOIN patient_program p ON p.patient_program_id = patient_state.patient_program_id",
                                  :conditions =>["patient_state.voided = 0 AND p.voided = 0 AND p.program_id = ? AND p.patient_id = ?",
                                  program_id,patient_obj.patient_id],:order => "date_enrolled DESC,start_date DESC")

        patient_visits[encounter_date] = self.new() if patient_visits[encounter_date].blank?
        patient_visits[encounter_date].outcome = state.program_workflow_state.concept.fullname rescue 'Unknown state'
        patient_visits[encounter_date].date_of_outcome = state.start_date rescue nil
      end
    end


    patient_visits
  end  

  def self.mastercard_visit_label(patient,date = Date.today)
    visit = self.visits(patient,date)[date] rescue {}
    return if visit.blank? 
    visit_data = self.mastercard_visit_data(visit)

    arv_number = patient.arv_number || patient.national_id
    pill_count = visit.pills.collect{|c|c.join(",")}.join(' ') rescue nil

    label = ZebraPrinter::StandardLabel.new
    label.draw_text("Printed: #{Date.today.strftime('%b %d %Y')}",597,280,0,1,1,1,false)
    label.draw_text("#{self.seen_by(patient,date)}",597,250,0,1,1,1,false)
    label.draw_text("#{date.strftime("%B %d %Y").upcase}",25,30,0,3,1,1,false)
    label.draw_text("#{arv_number}",565,30,0,3,1,1,true)
    label.draw_text("#{patient.name}(#{patient.person.sex.first})",25,60,0,3,1,1,false)
    label.draw_text("#{'(' + visit.visit_by + ')' unless visit.visit_by.blank?}",255,30,0,2,1,1,false)
    label.draw_text("#{visit.height.to_s + 'cm' if !visit.height.blank?}  #{visit.weight.to_s + 'kg' if !visit.weight.blank?}  #{'BMI:' + visit.bmi.to_s if !visit.bmi.blank?} #{'(PC:' + pill_count[0..24] + ')' unless pill_count.blank?}",25,95,0,2,1,1,false)
    label.draw_text("SE",25,130,0,3,1,1,false)
    label.draw_text("TB",110,130,0,3,1,1,false)
    label.draw_text("Adh",185,130,0,3,1,1,false)
    label.draw_text("DRUG(S) GIVEN",255,130,0,3,1,1,false)
    label.draw_text("OUTC",577,130,0,3,1,1,false)
    label.draw_line(25,150,800,5)
    label.draw_text("#{visit.tb_status}",110,160,0,2,1,1,false)
    label.draw_text("#{self.adherence_to_show(visit.adherence).gsub('%', '\\\\%') rescue nil}",185,160,0,2,1,1,false)
    label.draw_text("#{visit_data['outcome']}",577,160,0,2,1,1,false)
    label.draw_text("#{visit_data['outcome_date']}",655,130,0,2,1,1,false)
    starting_index = 25
    start_line = 160

    visit_data.each{|key,values|
      data = values.last rescue nil
      next if data.blank?
      bold = false
      #bold = true if key.include?("side_eff") and data !="None"
      #bold = true if key.include?("arv_given") 
      starting_index = values.first.to_i
      starting_line = start_line 
      starting_line = start_line + 30 if key.include?("2")
      starting_line = start_line + 60 if key.include?("3")
      starting_line = start_line + 90 if key.include?("4")
      starting_line = start_line + 120 if key.include?("5")
      starting_line = start_line + 150 if key.include?("6")
      starting_line = start_line + 180 if key.include?("7")
      starting_line = start_line + 210 if key.include?("8")
      starting_line = start_line + 240 if key.include?("9")
      next if starting_index == 0
      label.draw_text("#{data}",starting_index,starting_line,0,2,1,1,bold)
    } rescue []
    label.print(1)
  end
  
  def self.adherence_to_show(adherence_data)
    #For now we will only show the adherence of the drug with the lowest/highest adherence %
    #i.e if a drug adherence is showing 86% and their is another drug with an adherence of 198%,then 
    #we will show the one with 198%.
    #in future we are planning to show all available drug adherences

    adherence_to_show = 0
    adherence_over_100 = 0
    adherence_below_100 = 0
    over_100_done = false
    below_100_done = false

    adherence_data.each{|drug,adh|
      next if adh.blank?
      drug_adherence = adh.to_i
      if drug_adherence <= 100
        adherence_below_100 = adh.to_i if adherence_below_100 == 0
        adherence_below_100 = adh.to_i if drug_adherence <= adherence_below_100
        below_100_done = true
      else
        adherence_over_100 = adh.to_i if adherence_over_100 == 0
        adherence_over_100 = adh.to_i if drug_adherence >= adherence_over_100
        over_100_done = true
      end

    }

    return if !over_100_done and !below_100_done
    over_100 = 0
    below_100 = 0
    over_100 = adherence_over_100 - 100 if over_100_done
    below_100 = 100 - adherence_below_100 if below_100_done

    return "#{adherence_over_100}%" if over_100 >= below_100 and over_100_done
    return "#{adherence_below_100}%"
  end

  def self.mastercard_visit_data(visit)
    return if visit.blank?
    data = {}

    data["outcome"] = visit.outcome rescue nil
    if visit.appointment_date and (data["outcome"].match(/ON ANTIRETROVIRALS/i) || data["outcome"].blank?)
      data["outcome"] = "Next: #{visit.appointment_date.strftime('%b %d %Y')}" 
    else
      data["outcome_date"] = "#{visit.date_of_outcome.to_date.strftime('%b %d %Y')}" if visit.date_of_outcome
    end

    count = 1
    visit.s_eff.split(",").each{|side_eff|
      data["side_eff#{count}"] = "25",side_eff[0..5]
      count+=1
    } if visit.s_eff

    count = 1
    (visit.gave).each do | drug, pills |
      string = "#{drug} (#{pills})"
      if string.length > 26
        line = string[0..25]
        line2 = string[26..-1] 
        data["arv_given#{count}"] = "255",line
        data["arv_given#{count+=1}"] = "255",line2
      else
        data["arv_given#{count}"] = "255",string
      end
      count+= 1
    end rescue []

    unless visit.cpt.blank?
      data["arv_given#{count}"] = "255","CPT (#{visit.cpt})" unless visit.cpt == 0
    end rescue []

    data
  end

  def self.seen_by(patient,date = Date.today)
    provider = patient.encounters.find_by_date(date).collect{|e| next unless e.name == 'ART VISIT' ; [e.name,e.creator]}.compact 
    provider_username = "#{'Seen by: ' + User.find(provider[0].last).username}" unless provider.blank?
    if provider_username.blank? 
      clinic_encounters = ["ART VISIT","HIV STAGING","ART ADHERENCE","TREATMENT",'DISPENSION','HIV RECEPTION']
      encounter_type_ids = EncounterType.find(:all,:conditions =>["name IN (?)",clinic_encounters]).collect{| e | e.id }
      encounter = Encounter.find(:first,:conditions =>["patient_id = ? AND encounter_type In (?)",
                  patient.id,encounter_type_ids],:order => "encounter_datetime DESC")
      provider_username = "#{'Recorded by: ' + User.find(encounter.creator).username}" rescue nil
    end
    provider_username
  end

end 
