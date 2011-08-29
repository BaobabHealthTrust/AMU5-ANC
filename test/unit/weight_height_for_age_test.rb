require File.dirname(__FILE__) + '/../test_helper'

class WeightHeightForAgeTest < ActiveSupport::TestCase 
  fixtures :weight_height_for_ages

  context "Weight heights for ages" do
    setup do
      @patient = Patient.first
      @person = @patient.person
    end
    should "be valid" do
      assert_equal 432, WeightHeightForAge.count
    end

    should "give patient weight and height values" do
      @person.birthdate = 212.months.ago.to_date
      @person.gender = 'F'

      assert_equal [56.6929206848145, 163.506042480469],
        WeightHeightForAge.median_weight_height(@person.age_in_months,
                                                @person.gender
                                               )

      @person.birthdate = 121.months.ago
      @person.gender = 'M'
      assert_equal 121, @person.age_in_months
      assert_equal [31.7425994873047, 137.97639465332],
        WeightHeightForAge.median_weight_height(@person.age_in_months,
                                                @person.gender
                                               )
    end

    should "give patient median height" do
      @person.birthdate = 124.months.ago.to_date
      @person.gender = 'M'
      assert_equal 139.377105712891,
        WeightHeightForAge.median_weight_height(@person.age_in_months,
                                                @person.gender
                                               ).last
    end

    should "give patient median weight" do
      @person.birthdate = 2.months.ago.to_date
      @person.gender = 'F'
      assert_equal 4.70863008499146,
        WeightHeightForAge.median_weight_height(@person.age_in_months,
                                                @person.gender
                                               ).first
    end
  end  
end