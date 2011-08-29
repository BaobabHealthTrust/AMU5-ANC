require File.dirname(__FILE__) + '/../test_helper'

class ObservationTest < ActiveSupport::TestCase
  fixtures :obs, :concept_name, :concept

  context "Observations" do
    should "be valid" do
      observation = Observation.new
      assert_not_nil(observation)
    end
    
    should "have a psuedo-property for patient_id" do
      observation = Observation.new
      observation.patient_id = 10
      assert_equal observation.person_id, 10
    end
    
    should "allow you to assign the concept by name" do
      observation = Observation.make(:concept_id => Concept[:diagnosis].id,
                                     :value_coded => nil, :value_text => 'x')
      observation.concept_name = ConceptName[:alcohol_counseling].name
      assert_equal observation.concept_id, 
                   ConceptName[:alcohol_counseling].concept_id
    end
    
    should "allow you to assign the value coded or text" do
      observation = Observation.new(:concept_id => Concept[:diagnosis].id,
                                     :value_coded => nil, :value_text => nil)
      observation.value_coded_or_text = ConceptName[:alcohol_counseling].name
      assert_equal observation.value_coded, 
                   ConceptName[:alcohol_counseling].concept_id
      assert_nil observation.value_text

      observation = Observation.new(:concept_id => Concept[:diagnosis].id,
                                    :value_coded => nil, :value_text => nil)
      observation.value_coded_or_text = "GIANT ROBOT TORSO MODE"
      assert_equal observation.value_text, "GIANT ROBOT TORSO MODE"
      assert_nil observation.value_coded
    end
    
    should "look up active concepts"
    
    should "find the most common active observation and sort by the answer" do
      observation = Observation.make(:concept_id => Concept[:diagnosis].id,
        :value_text => nil,
        :value_coded => Concept[:extrapulmonary_tuberculosis_without_lymphadenopathy].id,
        :value_coded_name_id => ConceptName[:extrapulmonary_tuberculosis_without_lymphadenopathy].concept_name_id,
        :value_datetime => nil)
      observation = Observation.make(:concept_id => Concept[:diagnosis].id,
        :value_text => nil,
        :value_coded => Concept[:extrapulmonary_tuberculosis_without_lymphadenopathy].id,
        :value_coded_name_id => ConceptName[:immune_reconstitution_inflammatory_syndrome_construct].concept_name_id,
        :value_datetime => nil)
      observation = Observation.make(:concept_id => Concept[:diagnosis].id,
        :value_text => nil,
        :value_coded => Concept[:extrapulmonary_tuberculosis_without_lymphadenopathy].id,
        :value_coded_name_id => ConceptName[:immune_reconstitution_inflammatory_syndrome_construct].concept_name_id,
        :value_datetime => nil)
      assert_equal Observation.find_most_common(Concept[:diagnosis].id, nil),
        [ConceptName[:immune_reconstitution_inflammatory_syndrome_construct].name,
         ConceptName[:extrapulmonary_tuberculosis_without_lymphadenopathy].name]
      assert_equal Observation.find_most_common(Concept[:diagnosis].id, "LYMPH"),
        [ConceptName[:extrapulmonary_tuberculosis_without_lymphadenopathy].name]
    end
    
    should "find the most common active observation values by text"
    should "find the most common active observation values by number"
    should "find the most common active observation values by date and time"
    should "find the most common active observation values by location"
    
    should "be displayable as a string" do
      observation = Observation.make(:concept_id => Concept[:diagnosis].id,
        :value_coded => Concept[:alcohol_counseling].id,
        :value_coded_name_id => ConceptName[:alcohol_counseling].id,
        :value_numeric => 1,
        :value_datetime => nil)
      assert_equal observation.to_s, "DIAGNOSIS: ALCOHOL COUNSELING 1.0"
    end
      
    should "be able to display the answer as a string" do
      observation = Observation.make(:concept_id => Concept[:diagnosis].id,
        :value_coded => Concept[:alcohol_counseling].id,
        :value_coded_name_id => ConceptName[:alcohol_counseling].id,
        :value_numeric => 1,
        :value_datetime => nil)
      assert_equal observation.answer_string, "ALCOHOL COUNSELING 1.0"
    end
  end
end
