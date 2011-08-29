require File.dirname(__FILE__) + '/../test_helper'

class WeightHeightTest < ActiveSupport::TestCase

  context "WeightHeight" do
    fixtures :patient

    should "be valid" do
      assert_not_nil WeightHeight.min_height('M', 0)
      assert_not_nil WeightHeight.min_height('F', 480)
    end

    should "return minimum and maximun height for patient" do
      # male
      patient = Patient.find(1)
      person = patient.person
      person.birthdate = 216.months.ago
      assert_equal 151.0, WeightHeight.min_height(person.gender,
                                                  person.age_in_months)

      assert_equal 183.0, WeightHeight.max_height(person.gender,
                                                  person.age_in_months)
      # female
      person.gender = 'F'
      assert_equal 142.0, WeightHeight.min_height(person.gender,
                                                  person.age_in_months)
      assert_equal 174.0, WeightHeight.max_height(person.gender,
                                                  person.age_in_months)
    end

    should "return minimum and maximum weight for patient" do
      # male
      patient = patient(:evan)
      person = patient.person
      assert_equal 34.0, WeightHeight.min_weight(person.gender, person.age_in_months)
      assert_equal 82.0, WeightHeight.max_weight(person.gender, person.age_in_months)

      # female
      person.gender = 'F'
      assert_equal 28.0, WeightHeight.min_weight(person.gender, person.age_in_months)
      assert_equal 76.0, WeightHeight.max_weight(person.gender, person.age_in_months)
    end

  end
end
