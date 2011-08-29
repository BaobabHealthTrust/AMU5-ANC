class GlobalProperty < ActiveRecord::Base
  set_table_name "global_property"
  set_primary_key "property"
  include Openmrs

  def to_s
    return "#{property}: #{property_value}"
  end  

  def self.use_user_selected_activities
    GlobalProperty.find_by_property('use.user.selected.activities').property_value == "yes" rescue false
  end
end
