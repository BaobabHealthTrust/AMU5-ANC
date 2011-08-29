require File.dirname(__FILE__) + '/../test_helper'

class ConceptTest < ActiveSupport::TestCase 
  fixtures :concept, :concept_name, :concept_answer, :concept_numeric
  
  context "Concepts" do
    should "be valid" do
      concept = Concept.make
      assert concept.valid?
    end

    should "search have answers for the concept" do
      c = Concept.find_by_name("REFERRALS ORDERED")
      answer = Concept.find_by_name("ADHERENCE COUNSELING")
      assert_contains c.concept_answers.map(&:answer), answer
    end  

    should "search the answers for the concept and return the subset" do
      c = Concept.find_by_name("REFERRALS ORDERED")
      answer = Concept.find_by_name("ALCOHOL COUNSELING")
      assert_contains c.concept_answers.limit("ALCOHOL").map(&:answer), answer
    end  
    
    should "have an associated concept numeric" do
      assert_equal concept_numeric(:height_limits), 
                   Concept.find_by_name("HEIGHT (CM)").concept_numeric
    end
    
  end
end