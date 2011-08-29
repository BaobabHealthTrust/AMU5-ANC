class EncounterTypesController < ApplicationController

  def index
        user_roles = UserRole.find(:all,:conditions =>["user_id = ?", User.current_user.id]).collect{|r|r.role}
        role_privileges = RolePrivilege.find(:all,:conditions => ["role IN (?)", user_roles])

        privileges = role_privileges.each.map{ |role_privilege_pair| role_privilege_pair["privilege"].humanize }

        @encounter_privilege_map = GlobalProperty.find_by_property("encounter_privilege_map").property_value.to_s rescue ''

        @encounter_privilege_map = @encounter_privilege_map.split(",")

        @encounter_privilege_hash = {}

        @encounter_privilege_map.each do |encounter_privilege|
            @encounter_privilege_hash[encounter_privilege.split(":").last.squish.humanize] = encounter_privilege.split(":").first.squish.humanize
        end

        roles_for_the_user = []
		
        privileges.each do |privilege|
            roles_for_the_user  << @encounter_privilege_hash[privilege] if !@encounter_privilege_hash[privilege].nil?
        end
        roles_for_the_user = roles_for_the_user.uniq

        if GlobalProperty.use_user_selected_activities
        #redirect_to "/user/activities?patient_id=#{params[:patient_id]}"
        end
        
        # TODO add clever sorting
        @encounter_types = EncounterType.find(:all).map{|enc|enc.name.gsub(/.*\//,"").gsub(/\..*/,"").humanize}
        @available_encounter_types = Dir.glob(RAILS_ROOT+"/app/views/encounters/*.rhtml").map{|file|file.gsub(/.*\//,"").gsub(/\..*/,"").humanize}
        @available_encounter_types -= @available_encounter_types - @encounter_types
				

        @available_encounter_types = ((@available_encounter_types) - ((@available_encounter_types - roles_for_the_user) + (roles_for_the_user - @available_encounter_types)))
        @available_encounter_types = @available_encounter_types.sort
  end

  def show
    redirect_to "/encounters/new/#{params["encounter_type"].downcase.gsub(/ /,"_")}?#{params.to_param}" and return
  end

end
