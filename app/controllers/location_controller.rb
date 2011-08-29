class LocationController < ApplicationController
    def management
        render :layout => "menu"
    end
    
    def new
        @act = 'create'
    end
    
    def search
            @names = Location.search(params[:search_string].to_s, params[:act].to_s)
            render :text => "<li>" + @names.map{|n| n } .join("</li><li>") + "</li>"           
    end

    def create
        clinic_name = params[:location_name]
        if Location.find_by_name(clinic_name[:clinic_name]) == nil then
            location = Location.new
            location.name = clinic_name[:clinic_name]
            location.creator  = User.current_user.id.to_s
            location.date_created  = Time.current.strftime("%Y-%m-%d %H:%M:%S")
            location.save rescue (result = false)

            location_tag_map = LocationTagMap.new
            location_tag_map.location_id = location.id
            location_tag_map.location_tag_id = LocationTag.find_by_name("Workstation location").id
            result = location_tag_map.save rescue (result = false)
            
            if result == true then 
               flash[:notice] = "location #{clinic_name[:clinic_name]} added successfully"
            else
               flash[:notice] = "location #{clinic_name[:clinic_name]} addition failed"
            end  
        else
            location_tag_map = LocationTagMap.new
            location_tag_map.location_id = Location.find_by_name(clinic_name[:clinic_name]).id
            location_tag_map.location_tag_id = LocationTag.find_by_name("Workstation location").id
            result = location_tag_map.save rescue (result = false)
            #raise result.to_s
            if result == true then 
               flash[:notice] = "location #{clinic_name[:clinic_name]} added successfully"
            else
               flash[:notice] = "<span style='color:red; display:block; background-color:#DDDDDD;'>location #{clinic_name[:clinic_name]} addition failed</span>"
            end
        end
        redirect_to "/clinic" and return
    end
    
    def delete
        clinic_name = params[:location_name]
        location_id = Location.find_by_name(clinic_name[:clinic_name]).id rescue -1
        location_tag_id = LocationTag.find_by_name("Workstation location").id rescue -1
        location_tag_map = LocationTagMap.find(location_tag_id, location_id) 
        result = location_tag_map.delete rescue false
        
        if result != false then 
           flash[:notice] = "location #{clinic_name[:clinic_name]} delete successfully"
        else
           flash[:notice] = "<span style='color:red; display:block; background-color:#DDDDDD;'>location #{clinic_name[:clinic_name]} deletion failed</span>"
        end
        redirect_to "/clinic" and return 
    end
    
    def new
        @act = params[:act]
    end
    def print
      location_name = params[:location_name][:clinic_name].to_s
      print_location_and_redirect("/location/location_label?location_name=#{location_name}", "/clinic/location_management")
    end
    
    def location_label
      print_string = Location.find_by_name(params[:location_name]).location_label
      send_data(print_string,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{params[:id]}#{rand(10000)}.lbl", :disposition => "inline")
    end
end
