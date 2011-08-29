require File.dirname(__FILE__) + '/../test_helper'

class WeightForHeightTest < ActiveSupport::TestCase 
  fixtures :weight_for_heights

  context "Weight for heights" do
    should "be valid" do
      assert_equal 326, WeightForHeight.count
    end

    should "give patient weight for height values" do
      assert_equal 3.41081, WeightForHeight.patient_weight_for_height_values[50.0]
      assert_equal 15.2, WeightForHeight.patient_weight_for_height_values[98.5]
      assert_nil WeightForHeight.patient_weight_for_height_values[nil]
      assert_nil WeightForHeight.patient_weight_for_height_values[0]
    end

  end  
end