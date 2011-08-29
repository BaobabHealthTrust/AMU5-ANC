class Task < ActiveRecord::Base
  set_table_name :task
  set_primary_key :task_id
  include Openmrs

  # Try to find the next task for the patient at the given location
  def self.next_task(location, patient, session_date = Date.today)
    if GlobalProperty.use_user_selected_activities
      return self.next_form(location , patient , session_date)
    end
    all_tasks = self.all(:order => 'sort_weight ASC')
    todays_encounters = patient.encounters.find_by_date(session_date)
    todays_encounter_types = todays_encounters.map{|e| e.type.name rescue ''}.uniq rescue []
    all_tasks.each do |task|
      next if todays_encounters.map{ | e | e.name }.include?(task.encounter_type)
      # Is the task for this location?
      next unless task.location.blank? || task.location == '*' || location.name.match(/#{task.location}/)

      # Have we already run this task?
      next if task.encounter_type.present? && todays_encounter_types.include?(task.encounter_type)

      # By default, we don't want to skip this task
      skip = false
 
      # Skip this task if this is a gender specific task and the gender does not match?
      # For example, if this is a female specific check and the patient is not female, we want to skip it
      skip = true if task.gender.present? && patient.person.gender != task.gender

      # Check for an observation made today with a specific value, skip this task unless that observation exists
      # For example, if this task is the art_clinician task we want to skip it unless REFER TO CLINICIAN = yes
      if task.has_obs_concept_id.present?
        if (task.has_obs_scope.blank? || task.has_obs_scope == 'TODAY')
          obs = Observation.first(:conditions => [
          'encounter_id IN (?) AND concept_id = ? AND (value_coded = ? OR value_drug = ? OR value_datetime = ? OR value_numeric = ? OR value_text = ?)',
          todays_encounters.map(&:encounter_id),
          task.has_obs_concept_id,
          task.has_obs_value_coded,
          task.has_obs_value_drug,
          task.has_obs_value_datetime,
          task.has_obs_value_numeric,
          task.has_obs_value_text])
        end
        
        # Only the most recent obs
        # For example, if there are mutliple REFER TO CLINICIAN = yes, than only take the most recent one
        if (task.has_obs_scope == 'RECENT')
          o = patient.person.observations.recent(1).first(:conditions => ['encounter_id IN (?) AND concept_id =? AND DATE(obs_datetime)=?', todays_encounters.map(&:encounter_id), task.has_obs_concept_id,session_date])
          obs = 0 if (!o.nil? && o.value_coded == task.has_obs_value_coded && o.value_drug == task.has_obs_value_drug &&
            o.value_datetime == task.has_obs_value_datetime && o.value_numeric == task.has_obs_value_numeric &&
            o.value_text == task.has_obs_value_text )
        end
          
        skip = true unless obs.present?
      end

      # Check for a particular current order type, skip this task unless the order exists
      # For example, if this task is /dispensation/new we want to skip it if there is not already a drug order
      if task.has_order_type_id.present?
        skip = true unless Order.unfinished.first(:conditions => {:order_type_id => task.has_order_type_id}).present?
      end

      # Check for a particular program at this location, skip this task if the patient is not in the required program
      # For example if this is the hiv_reception task, we want to skip it if the patient is not currently in the HIV PROGRAM
      if task.has_program_id.present? && (task.has_program_workflow_state_id.blank? || task.has_program_workflow_state_id == '*')
        patient_program = PatientProgram.current.first(:conditions => [
          'patient_program.patient_id = ? AND patient_program.location_id = ? AND patient_program.program_id = ?',
          patient.patient_id,
          Location.current_health_center.location_id,
          task.has_program_id])        
        skip = true unless patient_program.present?
      end

      # Check for a particular program state at this location, skip this task if the patient does not have the required program/state
      # For example if this is the art_followup task, we want to skip it if the patient is not currently in the HIV PROGRAM with the state FOLLOWING
      if task.has_program_id.present? && task.has_program_workflow_state_id.present?
        patient_state = PatientState.current.first(:conditions => [
          'patient_program.patient_id = ? AND patient_program.location_id = ? AND patient_program.program_id = ? AND patient_state.state = ?',
          patient.patient_id,
          Location.current_health_center.location_id,
          task.has_program_id,
          task.has_program_workflow_state_id], :include => :patient_program)        
        skip = true unless patient_state.present?
      end
      
      # Check for a particular relationship, skip this task if the patient does not have the relationship
      # For example, if there is a CHW training update, skip this task if the person is not a CHW
      if task.has_relationship_type_id.present?        
        skip = true unless patient.relationships.first(
          :conditions => ['relationship.relationship = ?', task.has_relationship_type_id])
      end
 
      # Check for a particular identifier at this location
      # For example, this patient can only get to the Pre-ART room if they already have a pre-ART number, otherwise they need to go back to registration
      if task.has_identifier_type_id.present?
        skip = true unless patient.patient_identifiers.first(
          :conditions => ['patient_identifier.identifier_type = ? AND patient_identifier.location_id = ?', task.has_identifier_type_id, Location.current_health_center.location_id])
      end
  
      if task.has_encounter_type_today.present?
        enc = nil
        if todays_encounters.collect{|e|e.name}.include?(task.has_encounter_type_today)
          enc = task.has_encounter_type_today
        end
        skip = true unless enc.present?
      end

      if task.encounter_type == 'ART ADHERENCE' and patient.drug_given_before(session_date).blank?
        skip = true
      end
      
      if task.encounter_type == 'ART VISIT' and (patient.reason_for_art_eligibility.blank? or patient.reason_for_art_eligibility.match(/unknown/i))
        skip = true
      end
      
      if task.encounter_type == 'HIV STAGING' and not (patient.reason_for_art_eligibility.blank? or patient.reason_for_art_eligibility.match(/unknown/i))
        skip = true
      end
      
      # Reverse the condition if the task wants the negative (for example, if the patient doesn't have a specific program yet, then run this task)
      skip = !skip if task.skip_if_has == 1

      # We need to skip this task for some reason
      next if skip

      if location.name.match(/HIV|ART/i) and not location.name.match(/Outpatient/i)
       task = self.validate_task(patient,task,location,session_date.to_date)
      end

      # Nothing failed, this is the next task, lets replace any macros
      task.url = task.url.gsub(/\{patient\}/, "#{patient.patient_id}")
      task.url = task.url.gsub(/\{person\}/, "#{patient.person.person_id rescue nil}")
      task.url = task.url.gsub(/\{location\}/, "#{location.location_id}")

      logger.debug "next_task: #{task.id} - #{task.description}"
      
      return task
    end
  end 
  
  def self.validate_task(patient, task, location, session_date = Date.today)
    #return task unless task.has_program_id == 1
    return task if task.encounter_type == 'REGISTRATION'
    # allow EID patients at HIV clinic, but don't validate tasks
    return task if task.has_program_id == 4
    
    #check if the latest HIV program is closed - if yes, the app should redirect the user to update state screen
    if patient.encounters.find_by_encounter_type(EncounterType.find_by_name('ART_INITIAL').id)
      latest_hiv_program = [] ; patient.patient_programs.collect{ | p |next unless p.program_id == 1 ; latest_hiv_program << p } 
      if latest_hiv_program.last.closed?
        task.url = '/patients/programs_dashboard/{patient}' ; task.encounter_type = 'Program enrolment'
        return task
      end rescue nil
    end

    return task if task.url == "/patients/show/{patient}"

    art_encounters = ['ART_INITIAL','HIV RECEPTION','VITALS','HIV STAGING','ART VISIT','ART ADHERENCE','TREATMENT','DISPENSING']

    #if the following happens - that means the patient is a transfer in and the reception are trying to stage from the transfer in sheet
    if task.encounter_type == 'HIV STAGING' and location.name.match(/RECEPTION/i)
      return task 
    end

    #if the following happens - that means the patient was refered to see a clinician
    if task.description.match(/REFER/i) and location.name.match(/Clinician/i)
      return task 
    end

    if patient.encounters.find_by_encounter_type(EncounterType.find_by_name(art_encounters[0]).id).blank? and task.encounter_type != art_encounters[0]
      task.url = "/patients/summary?patient_id={patient}&skipped={encounter_type}" 
      task.url = task.url.gsub(/\{encounter_type\}/, "#{art_encounters[0].gsub(' ','_')}") 
      return task
    elsif patient.encounters.find_by_encounter_type(EncounterType.find_by_name(art_encounters[0]).id).blank? and task.encounter_type == art_encounters[0]
      return task
    end
    
    hiv_reception = Encounter.find(:first,
                                   :conditions =>["patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = ?",
                                   patient.id,EncounterType.find_by_name(art_encounters[1]).id,session_date],
                                   :order =>'encounter_datetime DESC')

    if hiv_reception.blank? and task.encounter_type != art_encounters[1]
      task.url = "/patients/summary?patient_id={patient}&skipped={encounter_type}" 
      task.url = task.url.gsub(/\{encounter_type\}/, "#{art_encounters[1].gsub(' ','_')}") 
      return task
    elsif hiv_reception.blank? and task.encounter_type == art_encounters[1]
      return task
    end



    reception = Encounter.find(:first,:conditions =>["patient_id = ? AND DATE(encounter_datetime) = ? AND encounter_type = ?",
                        patient.id,session_date,EncounterType.find_by_name(art_encounters[1]).id]).collect{|r|r.to_s}.join(',') rescue ''
    
    if reception.match(/PATIENT PRESENT FOR CONSULTATION:  YES/i)
      vitals = Encounter.find(:first,
                              :conditions =>["patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = ?",
                              patient.id,EncounterType.find_by_name(art_encounters[2]).id,session_date],
                              :order =>'encounter_datetime DESC')

      if vitals.blank? and task.encounter_type != art_encounters[2]
        task.url = "/patients/summary?patient_id={patient}&skipped={encounter_type}" 
        task.url = task.url.gsub(/\{encounter_type\}/, "#{art_encounters[2].gsub(' ','_')}") 
        return task
      elsif vitals.blank? and task.encounter_type == art_encounters[2]
        return task
      end
    end

    hiv_staging = patient.encounters.find_by_encounter_type(EncounterType.find_by_name(art_encounters[3]).id)
    art_reason = patient_obj.person.observations.recent(1).question("REASON FOR ART ELIGIBILITY").all rescue nil
    reasons = art_reason.map{|c|ConceptName.find(c.value_coded_name_id).name}.join(',') rescue ''

    if ((reasons.blank?) and (task.encounter_type == art_encounters[3]))
      return task
    elsif hiv_staging.blank? and task.encounter_type != art_encounters[3]
      task.url = "/patients/summary?patient_id={patient}&skipped={encounter_type}" 
      task.url = task.url.gsub(/\{encounter_type\}/, "#{art_encounters[3].gsub(' ','_')}") 
      return task
    elsif hiv_staging.blank? and task.encounter_type == art_encounters[3]
      return task
    end

    pre_art_visit = Encounter.find(:first,
                                   :conditions =>["patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = ?",
                                   patient.id,EncounterType.find_by_name('PART_FOLLOWUP').id,session_date],
                                   :order =>'encounter_datetime DESC',:limit => 1)

    if pre_art_visit.blank?
      art_visit = Encounter.find(:first,
                                     :conditions =>["patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = ?",
                                     patient.id,EncounterType.find_by_name(art_encounters[4]).id,session_date],
                                     :order =>'encounter_datetime DESC',:limit => 1)

      if art_visit.blank? and task.encounter_type != art_encounters[4]
        #checks if we need to do a pre art visit
        if task.encounter_type == 'PART_FOLLOWUP' 
          return task
        elsif reasons.upcase == 'UNKNOWN' or reasons.blank?
          task.url = "/patients/summary?patient_id={patient}&skipped={encounter_type}" 
          task.url = task.url.gsub(/\{encounter_type\}/, "PRE_ART_FOLLOWUP") 
          return task
        end

        task.url = "/patients/summary?patient_id={patient}&skipped={encounter_type}" 
        task.url = task.url.gsub(/\{encounter_type\}/, "#{art_encounters[4].gsub(' ','_')}") 
        return task
      elsif art_visit.blank? and task.encounter_type == art_encounters[4]
        return task
      end
    end

    unless patient.drug_given_before(session_date).blank?
      art_adherance = Encounter.find(:first,
                                     :conditions =>["patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = ?",
                                     patient.id,EncounterType.find_by_name(art_encounters[5]).id,session_date],
                                     :order =>'encounter_datetime DESC',:limit => 1)
      
      if art_adherance.blank? and task.encounter_type != art_encounters[5]
        task.url = "/patients/summary?patient_id={patient}&skipped={encounter_type}" 
        task.url = task.url.gsub(/\{encounter_type\}/, "#{art_encounters[5].gsub(' ','_')}") 
        return task
      elsif art_adherance.blank? and task.encounter_type == art_encounters[5]
        return task
      end
    end

    if patient.prescribe_arv_this_visit(session_date)
      art_treatment = Encounter.find(:first,
                                     :conditions =>["patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = ?",
                                     patient.id,EncounterType.find_by_name(art_encounters[6]).id,session_date],
                                     :order =>'encounter_datetime DESC',:limit => 1)
      if art_treatment.blank? and task.encounter_type != art_encounters[6]
        task.url = "/patients/summary?patient_id={patient}&skipped={encounter_type}" 
        task.url = task.url.gsub(/\{encounter_type\}/, "#{art_encounters[6].gsub(' ','_')}") 
        return task
      elsif art_treatment.blank? and task.encounter_type == art_encounters[6]
        return task
      end
    end

    task
  end 

  def self.next_form(location , patient , session_date = Date.today)
    #for Oupatient departments
    task = self.first rescue self.new()
    if location.name.match(/Outpatient/i)
      opd_reception = Encounter.find(:first,:conditions =>["patient_id = ? AND DATE(encounter_datetime) = ? AND encounter_type = ?",
                        patient.id,session_date,EncounterType.find_by_name('OUTPATIENT RECEPTION').id])
      if opd_reception.blank?
        task.url = "/encounters/new/opd_reception?show&patient_id=#{patient.id}"
        task.encounter_type = 'OUTPATIENT RECEPTION'
      else
        task.encounter_type = 'Patient dashboard ...'
        task.url = "/patients/show/#{patient.id}"
      end
      return task
    end
    
    if User.current_user.activities.include?('Manage Lab Orders') or User.current_user.activities.include?('Manage Lab Results') or
       User.current_user.activities.include?('Manage Sputum Submissions') or User.current_user.activities.include?('Manage TB Clinic Visits') or
       User.current_user.activities.include?('Manage TB Reception Visits') or User.current_user.activities.include?('Manage TB Registration Visits') or
       User.current_user.activities.include?('Manage HIV Status Visits') 
         return self.tb_next_form(location , patient , session_date)
    end
     
    #we get the sequence of clinic questions(encounters) form the GlobalProperty table
    #property: list.of.clinical.encounters.sequentially
    #property_value: ?

    #valid privileges for ART visit ....
    #1. Manage Vitals - VITALS
    #2. Manage pre ART visits - PART_FOLLOWUP
    #3. Manage HIV staging visits - HIV STAGING
    #4. Manage HIV reception visits - HIV RECEPTION
    #5. Manage HIV first visit - ART_INITIAL
    #6. Manage drug dispensations - DISPENSING
    #7. Manage ART visits - ART VISIT
    #8. Manage TB reception visits -? 
    #9. Manage prescriptions - TREATMENT
    #10. Manage appointments - APPOINTMENT
    #11. Manage ART adherence - ART ADHERENCE

    encounters_sequentially = GlobalProperty.find_by_property('list.of.clinical.encounters.sequentially')
    encounters = encounters_sequentially.property_value.split(',') rescue []
    user_selected_activities = User.current_user.activities.collect{|a| a.upcase }.join(',') rescue []
    if encounters.blank? or user_selected_activities.blank?
      task.url = "/patients/show/#{patient.id}"
      return task
    end
    art_reason = patient.person.observations.recent(1).question("REASON FOR ART ELIGIBILITY").all rescue nil
    reason_for_art = art_reason.map{|c|ConceptName.find(c.value_coded_name_id).name}.join(',') rescue ''
    
    encounters.each do | type |
      encounter_available = Encounter.find(:first,:conditions =>["patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = ?",
                                     patient.id,EncounterType.find_by_name(type).id,session_date],
                                     :order =>'encounter_datetime DESC',:limit => 1)
      reception = Encounter.find(:first,:conditions =>["patient_id = ? AND DATE(encounter_datetime) = ? AND encounter_type = ?",
                        patient.id,session_date,EncounterType.find_by_name('HIV RECEPTION').id]).observations.collect{| r | r.to_s}.join(',') rescue ''
        
      task.encounter_type = type 
      case type
        when 'VITALS'
          if encounter_available.blank? and user_selected_activities.match(/Manage Vitals/i) 
            task.url = "/encounters/new/vitals?patient_id=#{patient.id}"
            return task
          elsif encounter_available.blank? and not user_selected_activities.match(/Manage Vitals/i) 
            task.url = "/patients/show/#{patient.id}"
            return task
          end if reception.match(/PATIENT PRESENT FOR CONSULTATION:  YES/i)
        when 'ART VISIT'
          if encounter_available.blank? and user_selected_activities.match(/Manage ART visits/i)
            task.url = "/encounters/new/art_visit?show&patient_id=#{patient.id}"
            return task
          elsif encounter_available.blank? and not user_selected_activities.match(/Manage ART visits/i)
            task.url = "/patients/show/#{patient.id}"
            return task
          end if not reason_for_art.upcase ==  'UNKNOWN'
        when 'PART_FOLLOWUP'
          if encounter_available.blank? and user_selected_activities.match(/Manage pre ART visits/i)
            task.url = "/encounters/new/pre_art_visit?show&patient_id=#{patient.id}"
            return task
          elsif encounter_available.blank? and not user_selected_activities.match(/Manage pre ART visits/i)
            task.url = "/patients/show/#{patient.id}"
            return task
          end if reason_for_art.upcase ==  'UNKNOWN'
        when 'HIV STAGING'
          if encounter_available.blank? and user_selected_activities.match(/Manage HIV staging visits/i) 
            extended_staging_questions = GlobalProperty.find_by_property('use.extended.staging.questions')
            extended_staging_questions = extended_staging_questions.property_value == 'yes' rescue false
            task.url = "/encounters/new/hiv_staging?show&patient_id=#{patient.id}" if not extended_staging_questions 
            task.url = "/encounters/new/llh_hiv_staging?show&patient_id=#{patient.id}" if extended_staging_questions
            return task
          elsif encounter_available.blank? and not user_selected_activities.match(/Manage HIV staging visits/i)
            task.url = "/patients/show/#{patient.id}"
            return task
          end if (reason_for_art.upcase ==  'UNKNOWN' or reason_for_art.blank?)
        when 'HIV RECEPTION'
          encounter_art_initial = Encounter.find(:first,:conditions =>["patient_id = ? AND encounter_type = ?",
                                         patient.id,EncounterType.find_by_name('ART_INITIAL').id],
                                         :order =>'encounter_datetime DESC',:limit => 1)
          transfer_in = encounter_art_initial.observations.collect{|r|r.to_s.strip.upcase}.include?('HAS TRANSFER LETTER: YES'.upcase)
          hiv_staging = Encounter.find(:first,:conditions =>["patient_id = ? AND encounter_type = ?",
                        patient.id,EncounterType.find_by_name('HIV STAGING').id],:order => "encounter_datetime DESC")
          
          if transfer_in and hiv_staging.blank? and user_selected_activities.match(/Manage HIV first visits/i)
            task.url = "/encounters/new/hiv_staging?show&patient_id=#{patient.id}" 
            task.encounter_type = 'HIV STAGING'
            return task
          elsif encounter_available.blank? and user_selected_activities.match(/Manage HIV reception visits/i)
            task.url = "/encounters/new/hiv_reception?show&patient_id=#{patient.id}"
            return task
          elsif encounter_available.blank? and not user_selected_activities.match(/Manage HIV reception visits/i)
            task.url = "/patients/show/#{patient.id}"
            return task
          end
        when 'ART_INITIAL'
          encounter_art_initial = Encounter.find(:first,:conditions =>["patient_id = ? AND encounter_type = ?",
                                         patient.id,EncounterType.find_by_name(type).id],
                                         :order =>'encounter_datetime DESC',:limit => 1)

          if encounter_art_initial.blank? and user_selected_activities.match(/Manage HIV first visits/i)
            task.url = "/encounters/new/art_initial?show&patient_id=#{patient.id}"
            return task
          elsif encounter_art_initial.blank? and not user_selected_activities.match(/Manage HIV first visits/i)
            task.url = "/patients/show/#{patient.id}"
            return task
          end
        when 'DISPENSING'
          treatment = Encounter.find(:first,:conditions =>["patient_id = ? AND DATE(encounter_datetime) = ? AND encounter_type = ?",
                            patient.id,session_date,EncounterType.find_by_name('TREATMENT').id])

          if encounter_available.blank? and user_selected_activities.match(/Manage drug dispensations/i)
            task.url = "/patients/treatment_dashboard/#{patient.id}"
            return task
          elsif encounter_available.blank? and not user_selected_activities.match(/Manage drug dispensations/i)
            task.url = "/patients/show/#{patient.id}"
            return task
          end if not treatment.blank?
        when 'TREATMENT'
          encounter_art_visit = Encounter.find(:first,:conditions =>["patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = ?",
                                   patient.id,EncounterType.find_by_name('ART VISIT').id,session_date],
                                   :order =>'encounter_datetime DESC,date_created DESC',:limit => 1)

          prescribe_arvs = encounter_art_visit.observations.map{|obs| obs.to_s.strip.upcase }.include? 'Prescribe ARVs this visit:  Yes'.upcase
          not_refer_to_clinician = encounter_art_visit.observations.map{|obs| obs.to_s.strip.upcase }.include? 'Refer to ART clinician:  No'.upcase

          if prescribe_arvs and not_refer_to_clinician 
            show_treatment = true
          else
            show_treatment = false
          end

          if encounter_available.blank? and user_selected_activities.match(/Manage prescriptions/i)
            task.url = "/regimens/new?patient_id=#{patient.id}"
            return task
          elsif encounter_available.blank? and not user_selected_activities.match(/Manage prescriptions/i)
            task.url = "/patients/show/#{patient.id}"
            return task
          end if show_treatment

          if not show_treatment
            if not encounter_art_visit.blank? and user_selected_activities.match(/Manage ART visits/i)
              task.url = "/encounters/new/art_visit?show&patient_id=#{patient.id}"
              return task
            elsif not encounter_art_visit.blank? and not user_selected_activities.match(/Manage ART visits/i)
              task.url = "/patients/show/#{patient.id}"
              return task
            end if not reason_for_art.upcase ==  'UNKNOWN'
          end
        when 'ART ADHERENCE'
          if encounter_available.blank? and user_selected_activities.match(/Manage ART adherence/i)
            task.url = "/encounters/new/art_adherence?show&patient_id=#{patient.id}"
            return task
          elsif encounter_available.blank? and not user_selected_activities.match(/Manage ART adherence/i)
            task.url = "/patients/show/#{patient.id}"
            return task
          end if not patient.drug_given_before(session_date).blank?
      end
    end
    #task.encounter_type = 'Visit complete ...'
    task.encounter_type = 'Patient dashboard ...'
    task.url = "/patients/show/#{patient.id}"
    return task
  end


  def self.tb_next_form(location , patient , session_date = Date.today)
    task = self.first rescue self.new()
     
    #we get the sequence of clinic questions(encounters) form the GlobalProperty table
    #property: list.of.clinical.encounters.sequentially
    #property_value: ?

    #valid privileges for ART visit ....
    #1. Manage TB Reception Visits - TB RECEPTION
    #2. Manage TB initial visits - TB_INITIAL
    #3. Manage Lab orders - LAB ORDERS
    #4. Manage sputum submission - SPUTUM SUBMISSION
    #5. Manage Lab results - LAB RESULTS
    #6. Manage TB registration - TB REGISTRATION
    #7. Manage TB followup - TB TREATMENT VISIT
    #8. Manage HIV status updates - UPDATE HIV STATUS
    #8. Manage prescriptions - TREATMENT
    #8. Manage dispensations - DISPENSING

    tb_encounters =  [
                      'TB RECEPTION','UPDATE HIV STATUS','LAB ORDERS','SPUTUM SUBMISSION','LAB RESULTS',
                      'TB_INITIAL','TB REGISTRATION','ART_INITIAL','VITALS','HIV STAGING','ART VISIT',
                      'TB CLINIC VISIT','TB TREATMENT VISIT','ART ADHERENCE','TB ADHERENCE','TREATMENT'
                     ] 
    user_selected_activities = User.current_user.activities.collect{|a| a.upcase }.join(',') rescue []
    if user_selected_activities.blank? or tb_encounters.blank?
      task.url = "/patients/show/#{patient.id}"
      return task
    end
    art_reason = patient.person.observations.recent(1).question("REASON FOR ART ELIGIBILITY").all rescue nil
    reason_for_art = art_reason.map{|c|ConceptName.find(c.value_coded_name_id).name}.join(',') rescue ''
    
    tb_reception_attributes = []
    tb_obs = Encounter.find(:first,:order => "encounter_datetime DESC",
                    :conditions => ["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
                    session_date,patient.id,EncounterType.find_by_name('TB RECEPTION').id]).observations rescue []
    (tb_obs || []).each do | obs |
      tb_reception_attributes << obs.to_s.strip 
    end

    tb_encounters.each do | type |
      task.encounter_type = type 
      case type
        when 'UPDATE HIV STATUS'
          next if patient.hiv_status.match(/Positive/i)
          next if patient.patient_programs.collect{|p|p.program.name}.include?('HIV PROGRAM') rescue nil

          hiv_status = Encounter.find(:first,:order => "encounter_datetime DESC",
                                      :conditions =>["encounter_datetime >= ? AND encounter_datetime <= ?
                                      AND patient_id = ? AND encounter_type = ?",(session_date.to_date - 3.month).strftime('%Y-%m-%d 00:00:00'),
                                      (session_date.to_date).strftime('%Y-%m-%d 23:59:59'),patient.id,EncounterType.find_by_name(type).id])

          if hiv_status.observations.map{|s|s.to_s.split(':').last.strip}.include?('Positive')
            next 
          end if not hiv_status.blank?

          if hiv_status.blank? and user_selected_activities.match(/Manage HIV Status Visits/i)
            task.url = "/encounters/new/hiv_status?show&patient_id=#{patient.id}"
            return task
          elsif hiv_status.blank? and not user_selected_activities.match(/Manage HIV Status Visits/i)
            task.url = "/patients/show/#{patient.id}"
            return task
          end
        when 'VITALS' 
          if not patient.hiv_status.match(/Positive/i) and not patient.tb_status.match(/treatment/i)
            next
          end 

          first_vitals = Encounter.find(:first,:order => "encounter_datetime DESC",
                                  :conditions =>["patient_id = ? AND encounter_type = ?",
                                  patient.id,EncounterType.find_by_name(type).id])

          if not patient.tb_status.match(/treatment/i) and not tb_reception_attributes.include?('Any need to see a clinician:  Yes') 
            next
          end if not patient.hiv_status.match(/Positive/i) 

          if patient.tb_status.match(/treatment/i) and not patient.hiv_status.match(/Positive/i)
            next
          end if not first_vitals.blank?

          vitals = Encounter.find(:first,:order => "encounter_datetime DESC",
                                  :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
                                  session_date.to_date,patient.id,EncounterType.find_by_name(type).id])

          if vitals.blank? and user_selected_activities.match(/Manage Vitals/i) 
            task.encounter_type = 'VITALS'
            task.url = "/encounters/new/vitals?patient_id=#{patient.id}"
            return task
          elsif vitals.blank? and not user_selected_activities.match(/Manage Vitals/i) 
            task.encounter_type = 'VITALS'
            task.url = "/patients/show/#{patient.id}"
            return task
          end 
        when 'TB RECEPTION'
          reception = Encounter.find(:first,:order => "encounter_datetime DESC",
                                     :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
                                     session_date.to_date,patient.id,EncounterType.find_by_name(type).id])

          if reception.blank? and user_selected_activities.match(/Manage TB Reception Visits/i)
            task.url = "/encounters/new/tb_reception?show&patient_id=#{patient.id}"
            return task
          elsif reception.blank? and not user_selected_activities.match(/Manage TB Reception Visits/i)
            task.url = "/patients/show/#{patient.id}"
            return task
          end
        when 'LAB ORDERS'
          reception = Observation.find(:first,:order => "encounter_datetime DESC",:joins => "INNER JOIN encounter USING(encounter_id)",
                                     :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ? AND concept_id = ?",
                                     session_date.to_date,patient.id,EncounterType.find_by_name('TB RECEPTION').id,
                                     ConceptName.find_by_name('TYPE OF VISIT').concept_id])

          lab_order = Encounter.find(:first,:order => "encounter_datetime DESC",
                                      :conditions =>["DATE(encounter_datetime) <= ? AND patient_id = ? AND encounter_type = ?",
                                      session_date.to_date ,patient.id,EncounterType.find_by_name(type).id])

          next_lab_encounter =  self.next_lab_encounter(lab_order , session_date)
          visit_reason = reception.to_s.split(':').last.strip.match(/Needs lab follow-up/i)

          if (lab_order.encounter_datetime.to_date == session_date.to_date)
            task.encounter_type = 'Patient dashboard ...'
            task.url = "/patients/show/#{patient.id}"
            return task
          end if visit_reason and not lab_order.blank? 

          if user_selected_activities.match(/Manage Lab Orders/i)
            task.url = "/encounters/new/lab_orders?show&patient_id=#{patient.id}"
            return task
          elsif user_selected_activities.match(/Manage Lab Orders/i)
            task.url = "/patients/show/#{patient.id}"
            return task
          end if (next_lab_encounter.blank? and visit_reason and lab_order.blank?)
        when 'SPUTUM SUBMISSION'
          reception = Observation.find(:first,:order => "encounter_datetime DESC",:joins => "INNER JOIN encounter USING(encounter_id)",
                                     :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ? AND concept_id = ?",
                                     session_date.to_date,patient.id,EncounterType.find_by_name('TB RECEPTION').id,
                                     ConceptName.find_by_name('TYPE OF VISIT').concept_id])

           previous_sputum_sub = Encounter.find(:first,:order => "encounter_datetime DESC",
                                      :conditions =>["DATE(encounter_datetime) <= ? AND patient_id = ? AND encounter_type = ?",
                                      session_date.to_date ,patient.id,EncounterType.find_by_name(type).id])


          next_lab_encounter =  self.next_lab_encounter(previous_sputum_sub , session_date)
          visit_reason = reception.to_s.split(':').last.strip.match(/Needs lab follow-up/i)
          visit_reason = reception.to_s.split(':').last.strip.match(/Needs lab follow-up/i) if visit_reason.blank?

          if (previous_sputum_sub.encounter_datetime.to_date == session_date.to_date)
            task.encounter_type = 'Patient dashboard ...'
            task.url = "/patients/show/#{patient.id}"
            return task
          end if not previous_sputum_sub.blank? 

          if not next_lab_encounter.blank?
            next
          end

          if tb_reception_attributes.include?('Reason for visit:  Clinical examination') and tb_reception_attributes.include?('Any need to see a clinician:  Yes')
            next
          elsif tb_reception_attributes.include?('Reason for visit:  Follow-up')
            next
          end if next_lab_encounter.blank? 



          if next_lab_encounter.blank? and previous_sputum_sub.encounter_datetime.to_date == session_date.to_date
            task.encounter_type = 'Patient dashboard ...'
            task.url = "/patients/show/#{patient.id}"
            return task
          end if not previous_sputum_sub.blank?

          if user_selected_activities.match(/Manage Sputum Submissions/i)
            task.url = "/encounters/new/sputum_submission?show&patient_id=#{patient.id}"
            return task
          end 
        when 'LAB RESULTS'
          reception = Observation.find(:first,:order => "encounter_datetime DESC",:joins => "INNER JOIN encounter USING(encounter_id)",
                                     :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ? AND concept_id = ?",
                                     session_date.to_date,patient.id,EncounterType.find_by_name('TB RECEPTION').id,
                                     ConceptName.find_by_name('TYPE OF VISIT').concept_id])

          lab_result = Encounter.find(:first,:order => "encounter_datetime DESC",
                                      :conditions =>["DATE(encounter_datetime) <= ? AND patient_id = ? AND encounter_type = ?",
                                      session_date.to_date ,patient.id,EncounterType.find_by_name(type).id])

          visit_reason = reception.to_s.split(':').last.strip.match(/Needs lab follow-up/i)
          next_lab_encounter =  self.next_lab_encounter(lab_result , session_date)

          if not next_lab_encounter.blank?
            next
          end 

          if tb_reception_attributes.include?('Reason for visit:  Clinical examination') and tb_reception_attributes.include?('Any need to see a clinician:  Yes')
            next
          elsif tb_reception_attributes.include?('Reason for visit:  Follow-up')
            next
          end if next_lab_encounter.blank? 

          if user_selected_activities.match(/Manage Lab Results/i)
            task.url = "/encounters/new/lab_results?show&patient_id=#{patient.id}"
            return task
          end 
        when 'TB CLINIC VISIT'
          obs_ans = Observation.find(Observation.find(:last, :conditions => ["person_id = ? AND concept_id = ? AND DATE(obs_datetime) = ?", 
                    patient.id, ConceptName.find_by_name("ANY NEED TO SEE A CLINICIAN").concept_id,session_date])).to_s.strip.squish rescue nil

          if not obs_ans.blank?
            next if obs_ans.match(/ANY NEED TO SEE A CLINICIAN: NO/i)
          end

          visit_type = Observation.find(Observation.find(:last, :conditions => ["person_id = ? AND concept_id = ? AND DATE(obs_datetime) = ?", 
                    patient.id, ConceptName.find_by_name("TYPE OF VISIT").concept_id,session_date])).to_s.strip.squish rescue nil

          if not visit_type.blank?  #and obs_ans.match(/ANY NEED TO SEE A CLINICIAN: NO/i)
            next if visit_type.match(/Reason for visit: Follow-up/i)
          end if obs_ans.blank?

          clinic_visit = Encounter.find(:first,:order => "encounter_datetime DESC",
                                      :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
                                      session_date.to_date ,patient.id,EncounterType.find_by_name(type).id])


          if clinic_visit.blank? and user_selected_activities.match(/Manage TB clinic visits/i)
            task.url = "/encounters/new/tb_clinic_visit?show&patient_id=#{patient.id}"
            return task
          elsif clinic_visit.blank? and not user_selected_activities.match(/Manage TB clinic visits/i)
            task.url = "/patients/show/#{patient.id}"
            return task
          end 
        when 'TB_INITIAL'
          next if not patient.tb_status.match(/treatment/i)
          tb_initial = Encounter.find(:first,:order => "encounter_datetime DESC",
                                      :conditions =>["patient_id = ? AND encounter_type = ?",
                                      patient.id,EncounterType.find_by_name(type).id])

          next if not tb_initial.blank?

          enrolled_in_tb_program = patient.patient_programs.collect{|p|p.program.name}.include?('TB PROGRAM') rescue false

          if user_selected_activities.match(/Manage TB initial visits/i)
            task.url = "/encounters/new/tb_initial?show&patient_id=#{patient.id}"
            return task
          elsif not user_selected_activities.match(/Manage TB initial visits/i)
            task.url = "/patients/show/#{patient.id}"
            return task
          end 
        when 'ART_INITIAL'
          next unless patient.hiv_status.match(/Positive/i)
        
          enrolled_in_hiv_program = Concept.find(Observation.find(:last, :conditions => ["person_id = ? AND concept_id = ?",patient.id, 
            ConceptName.find_by_name("Patient enrolled in IMB HIV program").concept_id]).value_coded).concept_names.map{|c|c.name}[0].upcase rescue nil
      
          next unless enrolled_in_hiv_program == 'YES'
  
          enrolled_in_hiv_program = patient.patient_programs.collect{|p|p.program.name}.include?('HIV PROGRAM') rescue false
          next if enrolled_in_hiv_program 

          art_initial = Encounter.find(:first,:conditions =>["patient_id = ? AND encounter_type = ?",
                                         patient.id,EncounterType.find_by_name(type).id],
                                         :order =>'encounter_datetime DESC',:limit => 1)

          if art_initial.blank? and user_selected_activities.match(/Manage HIV first visits/i)
            task.url = "/encounters/new/art_initial?show&patient_id=#{patient.id}"
            return task
          elsif art_initial.blank? and not user_selected_activities.match(/Manage HIV first visits/i)
            task.url = "/patients/show/#{patient.id}"
            return task
          end
        when 'HIV STAGING'
          #checks if vitals have been taken already 
          vitals = self.checks_if_vitals_are_need(patient,session_date,task,user_selected_activities)
          return vitals unless vitals.blank?

          enrolled_in_hiv_program = Concept.find(Observation.find(:last, :conditions => ["person_id = ? AND concept_id = ?",patient.id, 
            ConceptName.find_by_name("Patient enrolled in IMB HIV program").concept_id]).value_coded).concept_names.map{|c|c.name}[0].upcase rescue nil

          next if enrolled_in_hiv_program == 'NO'

          next unless patient.hiv_status.match(/Positive/i)
          hiv_staging = Encounter.find(:first,:order => "encounter_datetime DESC",
                                      :conditions =>["patient_id = ? AND encounter_type = ?",
                                      patient.id,EncounterType.find_by_name(type).id])

          if hiv_staging.blank? and user_selected_activities.match(/Manage HIV staging visits/i) 
            extended_staging_questions = GlobalProperty.find_by_property('use.extended.staging.questions')
            extended_staging_questions = extended_staging_questions.property_value == 'yes' rescue false
            task.url = "/encounters/new/hiv_staging?show&patient_id=#{patient.id}" if not extended_staging_questions 
            task.url = "/encounters/new/llh_hiv_staging?show&patient_id=#{patient.id}" if extended_staging_questions
            return task
          elsif hiv_staging.blank? and not user_selected_activities.match(/Manage HIV staging visits/i)
            task.url = "/patients/show/#{patient.id}"
            return task
          end if (reason_for_art.upcase ==  'UNKNOWN' or reason_for_art.blank?)
        when 'TB REGISTRATION'
          next unless patient.tb_status.match(/treatment/i)
          tb_registration = Encounter.find(:first,:order => "encounter_datetime DESC",
                                      :conditions =>["patient_id = ? AND encounter_type = ?",
                                      patient.id,EncounterType.find_by_name(type).id])

          next if not tb_registration.blank?
          enrolled_in_tb_program = patient.patient_programs.collect{|p|p.program.name}.include?('TB PROGRAM') rescue false
    
          if user_selected_activities.match(/Manage TB Registration visits/i)
            task.url = "/encounters/new/tb_registration?show&patient_id=#{patient.id}"
            return task
          elsif not user_selected_activities.match(/Manage TB Registration visits/i)
            task.url = "/patients/show/#{patient.id}"
            return task
          end 
        when 'TB TREATMENT VISIT'
          #checks if vitals have been taken already 
          vitals = self.checks_if_vitals_are_need(patient,session_date,task,user_selected_activities)
          return vitals unless vitals.blank?

          next if not patient.tb_status.match(/treatment/i)
          tb_registration = Encounter.find(:first,:order => "encounter_datetime DESC",
                                      :conditions =>["patient_id = ? AND encounter_type = ?",
                                      patient.id,EncounterType.find_by_name('TB REGISTRATION').id])

          tb_followup = Encounter.find(:first,:order => "encounter_datetime DESC",
                                      :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
                                      session_date.to_date,patient.id,EncounterType.find_by_name(type).id])
=begin
          if (tb_followup.encounter_datetime.to_date == tb_registration.encounter_datetime.to_date)
            next
          end if not tb_followup.blank? and not tb_registration.blank?
=end
          if tb_registration.blank?
            task.encounter_type = 'TB PROGRAM ENROLMENT'
            task.url = "/patients/show/#{patient.id}"
            return task
          end

          if tb_followup.blank? and user_selected_activities.match(/Manage TB Registration visits/i)
            task.url = "/encounters/new/tb_treatment_visit?show&patient_id=#{patient.id}"
            return task
          elsif tb_followup.blank? and not user_selected_activities.match(/Manage TB Registration visits/i)
            task.url = "/patients/show/#{patient.id}"
            return task
          end
        when 'ART VISIT'  
          next unless patient.patient_programs.collect{|p|p.program.name}.include?('HIV PROGRAM') rescue false
          clinic_visit = Encounter.find(:first,:order => "encounter_datetime DESC",
                                    :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
                                    session_date.to_date,patient.id,EncounterType.find_by_name('TB CLINIC VISIT').id])
          goto_art_visit = clinic_visit.observations.map{|obs| obs.to_s.strip.upcase }.include? 'ART visit:  Yes'.upcase rescue false
          goto_art_visit_answered = clinic_visit.observations.map{|obs| obs.to_s.strip.upcase }.include? 'ART visit:'.upcase rescue false

          next if not goto_art_visit and goto_art_visit_answered
          

          pre_art_visit = Encounter.find(:first,:order => "encounter_datetime DESC",
                                    :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
                                    session_date.to_date,patient.id,EncounterType.find_by_name('PART_FOLLOWUP').id])

          if pre_art_visit.blank? and user_selected_activities.match(/Manage pre ART visits/i)
            task.encounter_type = 'Pre ART visit'
            task.url = "/encounters/new/pre_art_visit?show&patient_id=#{patient.id}"
            return task
          elsif pre_art_visit.blank? and not user_selected_activities.match(/Manage pre ART visits/i)
            task.encounter_type = 'Pre ART visit'
            task.url = "/patients/show/#{patient.id}"
            return task
          end if reason_for_art.upcase ==  'UNKNOWN' or reason_for_art.blank?

          art_visit = Encounter.find(:first,:order => "encounter_datetime DESC",
                                    :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
                                    session_date.to_date,patient.id,EncounterType.find_by_name(type).id])

          if art_visit.blank? and user_selected_activities.match(/Manage ART visits/i)
            task.url = "/encounters/new/art_visit?show&patient_id=#{patient.id}"
            return task
          elsif art_visit.blank? and not user_selected_activities.match(/Manage ART visits/i)
            task.url = "/patients/show/#{patient.id}"
            return task
          end if not reason_for_art.upcase ==  'UNKNOWN'
        when 'TB ADHERENCE'
          drugs_given_before = (not patient.drug_given_before(session_date).prescriptions.blank?) rescue false
           
          tb_adherence = Encounter.find(:first,:order => "encounter_datetime DESC",
                                    :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
                                    session_date.to_date,patient.id,EncounterType.find_by_name(type).id])

          if tb_adherence.blank? and user_selected_activities.match(/Manage TB adherence/i)
            task.url = "/encounters/new/tb_adherence?show&patient_id=#{patient.id}"
            return task
          elsif tb_adherence.blank? and not user_selected_activities.match(/Manage TB adherence/i)
            task.url = "/patients/show/#{patient.id}"
            return task
          end if drugs_given_before
        when 'ART ADHERENCE'
          art_drugs_given_before = (not patient.drug_given_before(session_date).arv.prescriptions.blank?) rescue false

          art_adherence = Encounter.find(:first,:order => "encounter_datetime DESC",
                                    :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
                                    session_date.to_date,patient.id,EncounterType.find_by_name(type).id])

          if art_adherence.blank? and user_selected_activities.match(/Manage ART adherence/i)
            task.url = "/encounters/new/art_adherence?show&patient_id=#{patient.id}"
            return task
          elsif art_adherence.blank? and not user_selected_activities.match(/Manage ART adherence/i)
            task.url = "/patients/show/#{patient.id}"
            return task
          end if art_drugs_given_before
        when 'TREATMENT' 
          treatment_encounter = Encounter.find(:first,:order => "encounter_datetime DESC",
                                    :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
                                    session_date.to_date,patient.id,EncounterType.find_by_name(type).id])

          encounter_tb_visit = Encounter.find(:first,:conditions =>["patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = ?",
                                   patient.id,EncounterType.find_by_name('TB TREATMENT VISIT').id,session_date],
                                   :order =>'encounter_datetime DESC,date_created DESC',:limit => 1)

          prescribe_drugs = encounter_tb_visit.observations.map{|obs| obs.to_s.strip.upcase }.include? 'Prescribe drugs:  Yes'.upcase rescue false

          if not prescribe_drugs 
            encounter_tb_clinic_visit = Encounter.find(:first,:conditions =>["patient_id = ? AND encounter_type = ? AND DATE(encounter_datetime) = ?",
                                   patient.id,EncounterType.find_by_name('TB CLINIC VISIT').id,session_date],
                                   :order =>'encounter_datetime DESC,date_created DESC',:limit => 1)

            prescribe_drugs = encounter_tb_clinic_visit.observations.map{|obs| obs.to_s.strip.upcase }.include? 'Prescribe drugs:  Yes'.upcase rescue false
          end

          if treatment_encounter.blank? and user_selected_activities.match(/Manage prescriptions/i)
            task.url = "/regimens/new?patient_id=#{patient.id}"
            return task
          elsif treatment_encounter.blank? and not user_selected_activities.match(/Manage prescriptions/i)
            task.url = "/patients/show/#{patient.id}"
            return task
          end if prescribe_drugs
      end
    end
    #task.encounter_type = 'Visit complete ...'
    task.encounter_type = 'Patient dashboard ...'
    task.url = "/patients/show/#{patient.id}"
    return task
  end

  private

  def self.next_lab_encounter(encounter = nil , session_date = Date.today)
    return if encounter.blank?
    case encounter.name.upcase
      when 'LAB ORDERS' 
        type = EncounterType.find_by_name('SPUTUM SUBMISSION').id
        sputum_sub = Encounter.find(:first,:joins => "INNER JOIN obs USING(encounter_id)",
               :conditions =>["obs.accession_number IN (?) AND patient_id = ? AND encounter_type = ?",
               encounter.observations.map{|r|r.accession_number}.compact,encounter.patient_id,type])

        return if sputum_sub.blank?
        return sputum_sub 
      when 'SPUTUM SUBMISSION'
        type = EncounterType.find_by_name('LAB RESULTS').id
        lab_results = Encounter.find(:first,:joins => "INNER JOIN obs USING(encounter_id)",
               :conditions =>["obs.accession_number IN (?) AND patient_id = ? AND encounter_type = ?",
               encounter.observations.map{|r|r.accession_number}.compact,encounter.patient_id,type])

        type = EncounterType.find_by_name('LAB ORDERS').id
        lab_order = Encounter.find(:first,:joins => "INNER JOIN obs USING(encounter_id)",
               :conditions =>["obs.accession_number IN (?) AND patient_id = ? AND encounter_type = ?",
               encounter.observations.map{|r|r.accession_number}.compact,encounter.patient_id,type])

        return lab_order if lab_results.blank? and not lab_order.blank?
        return if lab_results.blank?
        return lab_results 
      when 'LAB RESULTS'
        type = EncounterType.find_by_name('SPUTUM SUBMISSION').id
        sputum_sub = Encounter.find(:first,:joins => "INNER JOIN obs USING(encounter_id)",
               :conditions =>["obs.accession_number IN (?) AND patient_id = ? AND encounter_type = ?",
               encounter.observations.map{|r|r.accession_number}.compact,encounter.patient_id,type])

        return if sputum_sub.blank?
        return sputum_sub 
    end
  end


  def self.checks_if_vitals_are_need(patient , session_date, task , user_selected_activities)
    first_vitals = Encounter.find(:first,:order => "encounter_datetime DESC",
                            :conditions =>["patient_id = ? AND encounter_type = ?",
                            patient.id,EncounterType.find_by_name('VITALS').id])

    if first_vitals.blank?
      task.encounter_type = 'VITALS'
      task.url = "/encounters/new/vitals?patient_id=#{patient.id}"
      return task
    end

    return if patient.tb_status.match(/treatment/i) and not patient.hiv_status.match(/Positive/i)

    vitals = Encounter.find(:first,:order => "encounter_datetime DESC",
                            :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
                            session_date.to_date,patient.id,EncounterType.find_by_name('VITALS').id])

    if vitals.blank? and user_selected_activities.match(/Manage Vitals/i) 
      task.encounter_type = 'VITALS'
      task.url = "/encounters/new/vitals?patient_id=#{patient.id}"
      return task
    elsif vitals.blank? and not user_selected_activities.match(/Manage Vitals/i) 
      task.encounter_type = 'VITALS'
      task.url = "/patients/show/#{patient.id}"
      return task
    end 
  end

end
