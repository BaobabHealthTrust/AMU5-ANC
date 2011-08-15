class ClinicController < ApplicationController
  def index
    @types = GlobalProperty.find_by_property("statistics.show_encounter_types").property_value rescue EncounterType.all.map(&:name).join(",")
    @types = @types.split(/,/)
    @me = Encounter.statistics(@types, :conditions => ['DATE(encounter_datetime) = DATE(NOW()) AND encounter.creator = ?', User.current_user.user_id])
    @today = Encounter.statistics(@types, :conditions => ['DATE(encounter_datetime) = DATE(NOW())'])
    @year = Encounter.statistics(@types, :conditions => ['YEAR(encounter_datetime) = YEAR(NOW())'])
    @ever = Encounter.statistics(@types)

    @facility = Location.current_health_center.name rescue ''

    @location = Location.find(session[:location_id]).name rescue ""

    @date = (session[:datetime].to_date rescue Date.today).strftime("%Y-%m-%d")

    @user = User.find(session[:user_id]) rescue nil

    @roles = User.find(session[:user_id]).user_roles.collect{|r| r.role} rescue []

    render :layout => 'dynamic-dashboard'
  end

  def reports
    @reports = [['/reports/select/','Reports']]
    # render :template => 'clinic/reports', :layout => 'clinic'
    render :layout => false
  end

  def supervision
    @supervision_tools = [["Data that was Updated", "summary_of_records_that_were_updated"],
                          ["Drug Adherence Level",    "adherence_histogram_for_all_patients_in_the_quarter"],
                          ["Visits by Day",           "visits_by_day"],
                          ["Non-eligible Patients in Cohort", "non_eligible_patients_in_cohort"]]

   @landing_dashboard = 'clinic_supervision'

    render :template => 'clinic/supervision', :layout => 'clinic' 
  end

  def properties
    render :template => 'clinic/properties', :layout => 'clinic' 
  end

  def printing
    render :template => 'clinic/printing', :layout => 'clinic' 
  end

  def users
    render :template => 'clinic/users', :layout => 'general'
  end

  def administration
    @reports = [['/clinic/users','User accounts/settings']]
    @landing_dashboard = 'clinic_administration'
    # render :template => 'clinic/administration', :layout => 'clinic'
    render :layout => false
  end

  def overview
    @types = GlobalProperty.find_by_property("statistics.show_encounter_types").property_value rescue EncounterType.all.map(&:name).join(",")
    @types = @types.split(/,/)
    @me = Encounter.statistics(@types, :conditions => ['DATE(encounter_datetime) = DATE(NOW()) AND encounter.creator = ?', User.current_user.user_id])
    @today = Encounter.statistics(@types, :conditions => ['DATE(encounter_datetime) = DATE(NOW())'])
    @year = Encounter.statistics(@types, :conditions => ['YEAR(encounter_datetime) = YEAR(NOW())'])
    @ever = Encounter.statistics(@types)
    # render :template => 'clinic/overview', :layout => 'clinic'
    render :layout => false
  end

end
