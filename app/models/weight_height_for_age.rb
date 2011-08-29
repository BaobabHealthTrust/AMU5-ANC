class WeightHeightForAge < ActiveRecord::Base
  set_table_name :weight_height_for_ages
	
  def self.median_weight_height(age_in_months, gender)
    gender = (gender == "M" ? "0" : "1")
    values = self.find(:all,
                       :conditions =>["age_in_months = ? and sex = ?",
                                      age_in_months,
                                      gender
                                     ]).first
    [values.median_weight, values.median_height] if values
  end
end
