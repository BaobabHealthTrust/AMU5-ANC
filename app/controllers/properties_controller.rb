class PropertiesController < ApplicationController
  def set_clinic_holidays
    @clinic_holidays = GlobalProperty.find_by_property('clinic.holidays').property_value rescue nil
    render :layout => "menu"
  end

  def create_clinic_holidays
    if request.post? and not params[:holidays].blank?
      clinic_holidays = GlobalProperty.find_by_property('clinic.holidays')
      if clinic_holidays.blank?
        clinic_holidays = GlobalProperty.new()  
        clinic_holidays.property = 'clinic.holidays'
        clinic_holidays.description = 'day month year when clinic will be closed'
      end
      clinic_holidays.property_value = params[:holidays]
      clinic_holidays.save 
      flash[:notice] = 'Date(s) successfully created.'
      redirect_to '/properties/clinic_holidays' and return
    end
    redirect_to '/properties/set_clinic_holidays' and return
  end

  def clinic_holidays
    @holidays = GlobalProperty.find_by_property('clinic.holidays').property_value rescue []
    @holidays = @holidays.split(',').collect{|date|date.to_date}.sort unless @holidays.blank?
    render :layout => "menu"
  end

  def clinic_days
    if request.post? 
      ['peads','all'].each do | age_group |
        if age_group == 'peads'
          clinic_days = GlobalProperty.find_by_property('peads.clinic.days')
          weekdays = params[:peadswkdays]
        else
          clinic_days = GlobalProperty.find_by_property('clinic.days')
          weekdays = params[:weekdays]
        end

        if clinic_days.blank?
          clinic_days = GlobalProperty.new()  
          clinic_days.property = 'clinic.days'
          clinic_days.property = 'peads.clinic.days' if age_group == 'peads'
          clinic_days.description = 'Week days when the clinic is open'
        end
        weekdays = weekdays.split(',').collect{ |wd|wd.capitalize }
        clinic_days.property_value = weekdays.join(',') 
        clinic_days.save 
      end
      flash[:notice] = "Week day(s) successfully created."
      redirect_to "/properties/clinic_days" and return
    end
    @peads_clinic_days = GlobalProperty.find_by_property('peads.clinic.days').property_value rescue nil
    @clinic_days = GlobalProperty.find_by_property('clinic.days').property_value rescue nil
    render :layout => "menu"
  end

  def show_clinic_days
    @clinic_days = week_days('clinic.days')
    @peads_clinic_days = week_days('peads.clinic.days')
    render :layout => "menu"
  end

  def week_days(property)
    wkdays = {}
    days = GlobalProperty.find_by_property(property).property_value rescue ''
    days.split(',').map do | day |
      wkdays[day] = 'X'
    end rescue nil
    return wkdays
  end

  def site_code
    if request.post?
      location = Location.find(Location.current_health_center.id)
      location.neighborhood_cell = params[:site_code]
      if location.save
        redirect_to "/clinic" and return  # /properties
      else
        flash[:error] = "Site code not created.  (#{params[:site_code]})"
      end
    end
  end

  def site_appointment_limit
    if request.post? and not params[:appointment_limit].blank?
      appointment_limit = GlobalProperty.find_by_property('clinic.appointment.limit')

      if appointment_limit.blank?
        appointment_limit = GlobalProperty.new()  
        appointment_limit.property = 'clinic.appointment.limit'
        appointment_limit.description = 'number of appointments allowed per clinic day'
      end
      appointment_limit.property_value = params[:appointment_limit]
      appointment_limit.save 
      # redirect_to "/clinic/properties" and return
      redirect_to "/clinic" and return
    end
  end
  
  def set_role_privileges
    if request.post?
      role = params[:role]['title']
      privileges = params[:role]['privileges']

      RolePrivilege.find(:all,:conditions => ["role = ?",role]).each do | privilege |
        privilege.destroy
      end

      privileges.each do | privilege |
        role_privilege = RolePrivilege.new()
        role_privilege.role = Role.find_by_role(role)
        role_privilege.privilege = Privilege.find_by_privilege(privilege)
        role_privilege.save
      end
      if params[:id]
        redirect_to "/patients/show/#{params[:id]}" and return
      else
        redirect_to "/clinic" and return
      end
    end
  end

  def selected_roles
    render :text => RolePrivilege.find(:all,
           :conditions =>["role = ?",
           params[:role]]).collect{|r|r.privilege.privilege}.join(',') and return
  end

  def creation
    if request.post?
      global_property = GlobalProperty.find_by_property(params[:property]) || GlobalProperty.new()
      global_property.property = params[:property]
      global_property.property_value = params[:property_value]
      global_property.save
      redirect_to '/clinic'
    end
  end

end
