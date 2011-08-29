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

    @user = User.find(session[:user_id]).name rescue ""

    @roles = User.find(session[:user_id]).user_roles.collect{|r| r.role} rescue []

    render :template => 'clinic/index', :layout => false
  end

  def reports
    @reports = [
      ["Cohort","/cohort_tool/cohort_menu"],
      ["Supervision","/clinic/supervision"],
      ["Data Cleaning Tools", "/report/data_cleaning"],
      ["Stock report","/drug/date_select"]
    ]

    render :template => 'clinic/reports', :layout => 'clinic' 
  end

  def supervision
    @supervision_tools = [["Data that was Updated","summary_of_records_that_were_updated"],
      ["Drug Adherence Level","adherence_histogram_for_all_patients_in_the_quarter"],
      ["Visits by Day", "visits_by_day"],
      ["Non-eligible Patients in Cohort", "non_eligible_patients_in_cohort"]]

    @landing_dashboard = 'clinic_supervision'

    render :template => 'clinic/supervision', :layout => 'clinic' 
  end

  def properties
    @settings = [
      ["Set clinic days","/properties/clinic_days"],
      ["View clinic holidays","/properties/clinic_holidays"],
      ["Set clinic holidays","/properties/set_clinic_holidays"],
      ["Set site code", "/properties/site_code"],
      ["Set appointment limit", "/properties/set_appointment_limit"]
    ]
    render :template => 'clinic/properties', :layout => 'clinic' 
  end

  def management
    @reports = [
      ["New stock","delivery"],
      ["Edit stock","edit_stock"],
      ["Print Barcode","print_barcode"],
      ["Expiring drugs","date_select"],
      ["Removed from shelves","date_select"],
      ["Stock report","date_select"]
    ]
    render :template => 'clinic/management', :layout => 'clinic' 
  end

  def printing
    render :template => 'clinic/printing', :layout => 'clinic' 
  end

  def users
    render :template => 'clinic/users', :layout => 'clinic' 
  end

  def administration
    @reports =  [
                  ['/clinic/users','User accounts/settings'],
                  ['/clinic/management','Drug Management'], 
                  ['/clinic/location_management','Location Management']
                ]
    @landing_dashboard = 'clinic_administration'
    render :template => 'clinic/administration', :layout => 'clinic' 
  end

  def overview_tab
    @types = GlobalProperty.find_by_property("statistics.show_encounter_types").property_value rescue EncounterType.all.map(&:name).join(",")
    @types = @types.split(/,/)
    @me = Encounter.statistics(@types, :conditions => ['DATE(encounter_datetime) = DATE(NOW()) AND encounter.creator = ?', User.current_user.user_id])
    @today = Encounter.statistics(@types, :conditions => ['DATE(encounter_datetime) = DATE(NOW())'])
    @year = Encounter.statistics(@types, :conditions => ['YEAR(encounter_datetime) = YEAR(NOW())'])
    @ever = Encounter.statistics(@types)

    simple_overview = GlobalProperty.find_by_property("simple_application_dashboard").property_value rescue nil
    if simple_overview != nil
      if simple_overview == 'true'
        render :template => 'clinic/overview_simple.rhtml' , :layout => false
        return
      end
    end
    render :layout => false
  end

  def reports_tab
    @reports = [
      ["Cohort","/cohort_tool/cohort_menu"],
      ["Supervision","/clinic/supervision_tab"],
      ["Data Cleaning Tools", "/clinic/data_cleaning_tab"]
    ]

    @reports = [
      ["Diagnosis","/drug/date_select?goto=/report/age_group_select?type=diagnosis"],
     # ["Patient Level Data","/drug/date_select?goto=/report/age_group_select?type=patient_level_data"],
      ["Disaggregated Diagnosis","/drug/date_select?goto=/report/age_group_select?type=disaggregated_diagnosis"],
      ["Referrals","/drug/date_select?goto=/report/opd?type=referrals"],
      #["Total Visits","/drug/date_select?goto=/report/age_group_select?type=total_visits"],
      #["User Stats","/drug/date_select?goto=/report/age_group_select?type=user_stats"],
      ["User Stats","/"],
     # ["Total registered","/drug/date_select?goto=/report/age_group_select?type=total_registered"],
      ["Diagnosis (By address)","/drug/date_select?goto=/report/age_group_select?type=diagnosis_by_address"],
      ["Diagnosis + demographics","/drug/date_select?goto=/report/age_group_select?type=diagnosis_by_demographics"]
    ] if Location.current_location.name.match(/Outpatient/i)
    render :layout => false
  end

  def data_cleaning_tab
    @reports = [
                 ['Missing Prescriptions' , '/cohort_tool/select?report_type=dispensations_without_prescriptions'],
                 ['Missing Dispensations' , '/cohort_tool/select?report_type=prescriptions_without_dispensations'],
                 ['Multiple Start Reasons' , '/cohort_tool/select?report_type=patients_with_multiple_start_reasons'],
                 ['Out of range ARV number' , '/cohort_tool/select?report_type=out_of_range_arv_number'],
                 ['Data Consistency Check' , '/cohort_tool/select?report_type=data_consistency_check']
               ] 
    render :layout => false
  end

  def properties_tab
    @settings = [
      ["Set clinic days","/properties/clinic_days"],
      ["View clinic holidays","/properties/clinic_holidays"],
      ["Set clinic holidays","/properties/set_clinic_holidays"],
      ["Set site code", "/properties/site_code"],
      ["Manage roles", "/properties/set_role_privileges"],
      ["Use extended staging format", "/properties/creation?value=use_extended_staging_format"],
      ["Use user selected task(s)", "/properties/creation?value=use_user_selected_activities"],
      ["Use filing numbers", "/properties/creation?value=use_filing_numbers"],
      ["Show lab results", "/properties/creation?value=show_lab_results"],
      ["Set appointment limit", "/properties/set_appointment_limit"]
    ]
    render :layout => false
  end

  def administration_tab
    @reports =  [
                  ['/clinic/users_tab','User accounts/settings'],
                  ['/clinic/location_management_tab','Location Management']
                ]
    if User.current_user.admin?
      @reports << ['/clinic/management_tab','Drug Management']
    end
    @landing_dashboard = 'clinic_administration'
    render :layout => false
  end

  def supervision_tab
    @reports = [
                 ["Data that was Updated","/cohort_tool/select?report_type=summary_of_records_that_were_updated"],
                 ["Drug Adherence Level","/cohort_tool/select?report_type=adherence_histogram_for_all_patients_in_the_quarter"],
                 ["Visits by Day", "/cohort_tool/select?report_type=visits_by_day"],
                 ["Non-eligible Patients in Cohort", "/cohort_tool/select?report_type=non_eligible_patients_in_cohort"]
               ]
    @landing_dashboard = 'clinic_supervision'
    render :layout => false
  end

  def users_tab
    render :layout => false
  end

  def location_management
    @reports =  [
                  ['/location/new?act=create','Add location'],
                  ['/location.new?act=delete','Delete location'], 
                  ['/location/new?act=print','Print location']
                ]
    render :template => 'clinic/location_management', :layout => 'clinic' 
  end

  def location_management_tab
    @reports =  [
                  ['/location/new?act=print','Print location']
                ]
    if User.current_user.admin?
      @reports << ['/location/new?act=create','Add location']
      @reports << ['/location/new?act=delete','Delete location']
    end
    render :layout => false
  end

  def management_tab
    @reports = [
      ["New stock","delivery"],
      ["Edit stock","edit_stock"],
      ["Print Barcode","print_barcode"],
      ["Expiring drugs","date_select"],
      ["Removed from shelves","date_select"],
      ["Stock report","date_select"]
    ]
    render :layout => false
  end

end
