class WeightForHeight < ActiveRecord::Base
  set_table_name :weight_for_heights

 def self.patient_weight_for_height_values
  # corrected_height = self.significant(patient_height) #correct height to the neares .5
   height_for_weight = Hash.new
   self.find(:all).each do |hwt|
     height_for_weight[hwt.supine_cm] = hwt.median_weight_height
   end
   height_for_weight  
 end

end
