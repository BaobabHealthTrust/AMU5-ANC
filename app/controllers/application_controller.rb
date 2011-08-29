class ApplicationController < ActionController::Base
  include AuthenticatedSystem

  require "fastercsv"

  helper :all
  helper_method :next_task
  filter_parameter_logging :password
  before_filter :login_required, :except => ['login', 'logout','demographics','create_remote', 'mastercard_printable']
  before_filter :location_required, :except => ['login', 'logout', 'location','demographics','create_remote', 'mastercard_printable']
  
  def rescue_action_in_public(exception)
    @message = exception.message
    @backtrace = exception.backtrace.join("\n") unless exception.nil?
    render :file => "#{RAILS_ROOT}/app/views/errors/error.rhtml", :layout=> false, :status => 404
  end if RAILS_ENV == 'development' || RAILS_ENV == 'test'

  def rescue_action(exception)
    @message = exception.message
    @backtrace = exception.backtrace.join("\n") unless exception.nil?
    render :file => "#{RAILS_ROOT}/app/views/errors/error.rhtml", :layout=> false, :status => 404
  end if RAILS_ENV == 'production'

  def next_task(patient)
    session_date = session[:datetime].to_date rescue Date.today
    task = Task.next_task(Location.current_location, patient,session_date)
    begin
      return task.url if task.present? && task.url.present?
      return "/patients/show/#{patient.id}" 
    rescue
      return "/patients/show/#{patient.id}" 
    end
  end

  def print_and_redirect(print_url, redirect_url, message = "Printing, please wait...", show_next_button = false, patient_id = nil)
    @print_url = print_url
    @redirect_url = redirect_url
    @message = message
    @show_next_button = show_next_button
    @patient_id = patient_id
    render :template => 'print/print', :layout => nil
  end
  
  def print_location_and_redirect(print_url, redirect_url, message = "Printing, please wait...", show_next_button = false, patient_id = nil)
    @print_url = print_url
    @redirect_url = redirect_url
    @message = message
    @show_next_button = show_next_button
    render :template => 'print/print_location', :layout => nil
  end

  def show_lab_results
    GlobalProperty.find_by_property('show.lab.results').property_value == "yes" rescue false
  end

  def use_filing_number
    GlobalProperty.find_by_property('use.filing.number').property_value == "yes" rescue false
  end    

  def generic_locations
    Location.workstation_locations
  end

  def site_prefix
    site_prefix = GlobalProperty.find_by_property("site_prefix").property_value rescue false
    return site_prefix
  end

  def use_user_selected_activities
    GlobalProperty.find_by_property('use.user.selected.activities').property_value == "yes" rescue false
  end

  # Convert a list +Concept+s of +Regimen+s for the given +Patient+ <tt>age</tt>
  # into select options. See also +EncountersController#arv_regimen_answers+
  def regimen_options(regimen_concepts, age)
    options = regimen_concepts.map{ |r|
      [r.concept_id,
       (r.concept_names.typed("SHORT").first ||
        r.concept_names.typed("FULLY_SPECIFIED").first).name]
    }

    options.collect{ |opt|
      opt_reg = Regimen.find(:all,
                             :select => 'regimen_index',
                             :conditions => ['concept_id = ?', opt[0]]
                            ).uniq.first
      if age >= 15
        suffix = "A"
      else
        suffix = "P"
      end

      #[opt[0], "#{opt_reg.regimen_index}#{suffix} - #{opt[1]}"]
		if opt_reg.regimen_index > -1
      		["#{opt_reg.regimen_index}#{suffix} - #{opt[1]}", opt[0]]
		else
      		["#{opt[1]}", opt[0]]
		end
    }.sort_by{|opt| opt[1]}
  end

private

  def find_patient
    @patient = Patient.find(params[:patient_id] || session[:patient_id] || params[:id]) rescue nil
  end
  
end
