require File.dirname(__FILE__) + '/../test_helper'

class PatientTest < ActiveSupport::TestCase
  fixtures :patient, :patient_identifier, :person_name, :person,
           :encounter, :encounter_type, :concept, :concept_name, :obs

  context "Patients" do
    should "be valid" do
      patient = Patient.make
      assert patient.valid?
    end

    should "refer to the patient identifiers" do
      assert_equal patient(:evan).patient_identifiers.count, 3
    end
    
    should "not include voided identifiers in the list of patient identifiers" do
      PatientIdentifier.find(:first).void
      assert_equal patient(:evan).patient_identifiers.count, 2
    end
    
    should "refer to the person" do
      assert_not_nil patient(:evan).person
    end

    should "refer to the patient encounters" do
      assert_equal patient(:evan).encounters.count, 3
    end

    should "not included voided encounters" do
      Encounter.find(:first).void
      assert_equal patient(:evan).encounters.count, 2
    end

    should "lookup encounters by date" do
      assert_equal patient(:evan).encounters.find_by_date("2001-01-01".to_date).size, 3
      assert_equal patient(:evan).encounters.find_by_date("2000-01-01".to_date).size, 0
    end

    should "return the national identifier" do
      assert_equal patient(:evan).national_id, "P1701210013"
    end

    should "create a new national identifier if none exists" do
      PatientIdentifier.find(:first).void
      assert_not_nil patient(:evan).national_id
    end

    should "not create a new national identifier if it is not forced"  do
      PatientIdentifier.find(:first).void
      #assert_nil patient(:evan).national_id(false)
    end

    should "format the national identifier with dashes" do
      PatientIdentifier.find(:first).void
      t = PatientIdentifierType.find_by_name("National id")
      patient(:evan).patient_identifiers.create(:identifier =>  "P123456789012", :identifier_type => t.id)
      assert_equal patient(:evan).national_id_with_dashes, "P1234-5678-9012"
    end

    should "print the national id label" do
      patient = patient(:evan)
      assert_equal patient.national_id_label, <<EOF

N
q801
Q329,026
ZT
B50,180,0,1,5,15,120,N,"P1701210013"
A40,50,0,2,2,2,N,"Evan Waters"
A40,96,0,2,2,2,N,"P1701-2100-13 09/Jun/1982(M)"
A40,142,0,2,2,2,N,"Katoleza"
P1
EOF
    end
    
    should "get the min weight for this patient based on their gender and age" do
      patient = patient(:evan)
      assert_equal patient.min_weight, 34.0    
    end
    
    should "get the max weight for this patient based on their gender and age" do
      patient = patient(:evan)
      assert_equal patient.max_weight, 82.0   
    end  

    should "get the min height for this patient based on their gender and age" do
      patient = patient(:evan)
      assert_equal patient.min_height, 151.0
    end
    
    should "get the max height for this patient based on their gender and age" do
      patient = patient(:evan)
      assert_equal patient.max_height, 183.0
    end  

    context "current diagnoses" do
      setup do
        @evan = patient(:evan)
        @encounter = Encounter.make(
          :encounter_type => EncounterType[:outpatient_diagnosis].encounter_type_id)
        @diagnosis = Observation.make(
          :encounter_id => @encounter.id, 
          :concept_id => Concept[:diagnosis].concept_id,
          :value_coded => Concept[:extrapulmonary_tuberculosis_without_lymphadenopathy].concept_id,
          :value_coded_name_id => ConceptName[:extrapulmonary_tuberculosis_without_lymphadenopathy].concept_name_id,
          :value_text => nil)
        @diagnosis_non_coded = Observation.make(
          :encounter_id => @encounter.id, 
          :concept_id => concept(:concept_03106).concept_id,
          :value_text => "HE IS TOO SUAVE")
      end
    
      should "include coded and non-coded diagnoses" do
        assert_equal [@diagnosis, @diagnosis_non_coded], @evan.current_diagnoses
      end
      
      should "not include non-diagnosis observations" do
        Observation.make(
          :encounter_id => @encounter.id, 
          :concept_id => concept(:concept_02218).concept_id,
          :value_numeric => 100)
        assert_equal [@diagnosis, @diagnosis_non_coded], @evan.current_diagnoses
      end
                  
      should "not include voided diagnoses in the list of current diagnoses" do
        @diagnosis.void
        assert_equal [@diagnosis_non_coded], @evan.current_diagnoses
      end

      should "not include diagnoses belonging to voided encounters in the list of current diagnoses" do
        @encounter.void
        assert_equal [], @evan.current_diagnoses
      end

      should "get current BMI alert" do
        assert_equal 60.0, @evan.current_weight
        assert_equal 191.0, @evan.current_height
        assert_equal 'Low BMI: Eligible for therapeutic feeding', @evan.current_bmi_alert

        weight_obs = @evan.person.observations.find_last(
            :conditions => ['voided = 0 AND concept_id = ?',
                            ConceptName.find_by_name('WT').concept_id])

        weight_obs.value_numeric = 90.0
        weight_obs.save
        assert_nil @evan.current_bmi_alert
      end

    end
  end
end
