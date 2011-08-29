class Outpatient 
  attr_accessor :patient_present, :primary_diagnosis, :secondary_diagnosis, :referal_destination, :treatment

  def self.visits(patient_obj)
    patient_visits = {}
    concept_names = []
    concept_names << 'REFERRAL CLINIC IF REFERRED'
    concept_names << 'WORKSTATION LOCATION'
    concept_names << 'DIAGNOSIS'
    concept_names << 'DRUGS DISPENSED'
    concept_names << 'OTHER DRUGS'
    
    concept_names.each do | concept_name |
      concept_id = ConceptName.find_by_name(concept_name).concept_id
      patient_observations = Observation.find(:all,:conditions => ["concept_id = ? and person_id = ?",
                                              concept_id,patient_obj.patient_id],:order => "obs.obs_datetime DESC")

      patient_observations.each do | obs |

        next if obs.blank? or obs.encounter.blank?

        visit_date = obs.obs_datetime.to_date
        patient_visits[visit_date] = Outpatient.new() if patient_visits[visit_date].blank?
        case concept_name
          when "DIAGNOSIS"
            patient_visits[visit_date].primary_diagnosis = [] if patient_visits[visit_date].primary_diagnosis.blank? 
            patient_visits[visit_date].primary_diagnosis << obs.to_s.split(':')[1].strip rescue nil
          when "REFERRAL CLINIC IF REFERRED"
            patient_visits[visit_date].referal_destination = obs.to_s.split(':')[1].strip rescue nil
          when "DRUGS DISPENSED"
            patient_visits[visit_date].treatment = [] if patient_visits[visit_date].treatment.blank? 
            patient_visits[visit_date].treatment << obs.to_s.split(':')[1].strip rescue nil
          when "OTHER DRUGS"
            patient_visits[visit_date].treatment = [] if patient_visits[visit_date].treatment.blank? 
            patient_visits[visit_date].treatment << obs.to_s.split(':')[1].strip rescue nil
          when "WORKSTATION LOCATION"
            if obs.encounter.name == "REGISTRATION"
              patient_visits[visit_date].patient_present = 'YES' 
            end
        end
      end
    end
    patient_visits
  end

end
