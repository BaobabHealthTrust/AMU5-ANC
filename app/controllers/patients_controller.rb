class PatientsController < ApplicationController
  before_filter :find_patient, :except => [:void]
  
  def show
    session[:mastercard_ids] = []
    session_date = session[:datetime].to_date rescue Date.today
    @encounters = @patient.encounters.find_by_date(session_date)
    @prescriptions = @patient.orders.unfinished.prescriptions.all
    @programs = @patient.patient_programs.all
    @alerts = @patient.alerts
    # This code is pretty hacky at the moment
    @restricted = ProgramLocationRestriction.all(:conditions => {:location_id => Location.current_health_center.id })
    @restricted.each do |restriction|    
      @encounters = restriction.filter_encounters(@encounters)
      @prescriptions = restriction.filter_orders(@prescriptions)
      @programs = restriction.filter_programs(@programs)
    end
    # render :template => 'dashboards/overview', :layout => 'dashboard'

    @date = (session[:datetime].to_date rescue Date.today).strftime("%Y-%m-%d")

     @location = Location.find(session[:location_id]).name rescue ""
     if @location.downcase == "outpatient" || params[:source]== 'opd'
        render :template => 'dashboards/opdtreatment_dashboard', :layout => false
     else
        render :template => 'patients/index', :layout => false
     end
  end

  def opdcard
    @patient = Patient.find(params[:id])
    render :layout => 'menu' 
  end

  def opdshow
    session_date = session[:datetime].to_date rescue Date.today
    encounter_types = EncounterType.find(:all,:conditions =>["name IN (?)",
        ['REGISTRATION','OUTPATIENT DIAGNOSIS','REFER PATIENT OUT?','OUTPATIENT RECEPTION','DISPENSING']]).map{|e|e.id}
    @encounters = Encounter.find(:all,:select => "encounter_id , name encounter_type_name, count(*) c",
      :joins => "INNER JOIN encounter_type ON encounter_type_id = encounter_type",
      :conditions =>["patient_id = ? AND encounter_type IN (?) AND DATE(encounter_datetime) = ?",
        params[:id],encounter_types,session_date],
      :group => 'encounter_type').collect do |rec| 
        if User.current_user.user_roles.map{|r|r.role}.join(',').match(/Registration|Clerk/i)
          next unless rec.observations[0].to_s.match(/Workstation location:   Outpatient/i)
        end
        [ rec.encounter_id , rec.encounter_type_name , rec.c ] 
      end
    
    render :template => 'dashboards/opdoverview_tab', :layout => false
  end

  def opdtreatment
    render :template => 'dashboards/opdtreatment_dashboard', :layout => false
  end

  def opdtreatment_tab
    @activities = [
      ["Visit card","/patients/opdcard/#{params[:id]}"],
      ["National ID (Print)","/patients/dashboard_print_national_id?id=#{params[:id]}&redirect=patients/opdtreatment"],
      ["Referrals", "/encounters/referral/#{params[:id]}"],
      ["Give drugs", "/encounters/opddrug_dispensing/#{params[:id]}"],
      ["Vitals", "/report/data_cleaning"],
      ["Outpatient diagnosis","/encounters/new?id=show&patient_id=#{params[:id]}&encounter_type=outpatient_diagnosis"]
    ]
    render :template => 'dashboards/opdtreatment_tab', :layout => false
  end

  def treatment
    #@prescriptions = @patient.orders.current.prescriptions.all
    type = EncounterType.find_by_name('TREATMENT')
    session_date = session[:datetime].to_date rescue Date.today
    @prescriptions = Order.find(:all,
      :joins => "INNER JOIN encounter e USING (encounter_id)",
      :conditions => ["encounter_type = ? AND e.patient_id = ? AND DATE(encounter_datetime) = ?",
        type.id,@patient.id,session_date])

    @restricted = ProgramLocationRestriction.all(:conditions => {:location_id => Location.current_health_center.id })
    @restricted.each do |restriction|
      @prescriptions = restriction.filter_orders(@prescriptions)
    end

    # render :template => 'dashboards/treatment', :layout => 'dashboard'
    render :template => 'dashboards/dispension_tab', :layout => false
  end

  def history_treatment
    #@prescriptions = @patient.orders.current.prescriptions.all
    type = EncounterType.find_by_name('TREATMENT')
    session_date = session[:datetime].to_date rescue Date.today
    @prescriptions = Order.find(:all,
      :joins => "INNER JOIN encounter e USING (encounter_id)",
      :conditions => ["encounter_type = ? AND e.patient_id = ?",type.id,@patient.id])

    @historical = @patient.orders.historical.prescriptions.all
    @restricted = ProgramLocationRestriction.all(:conditions => {:location_id => Location.current_health_center.id })
    @restricted.each do |restriction|
      @historical = restriction.filter_orders(@historical)
    end
    # render :template => 'dashboards/treatment', :layout => 'dashboard'
    render :template => 'dashboards/treatment_tab', :layout => false
  end

  def guardians
    if @patient.blank?
    	redirect_to :'clinic'
    	return
    else
		  @relationships = @patient.relationships rescue []
		  @restricted = ProgramLocationRestriction.all(:conditions => {:location_id => Location.current_health_center.id })
		  @restricted.each do |restriction|
		    @relationships = restriction.filter_relationships(@relationships)
		  end
    	render :template => 'dashboards/relationships_tab', :layout => false
  	end
  end

  def relationships
    if @patient.blank?
    	redirect_to :'clinic'
    	return
    else
      next_form = next_task(@patient)
      redirect_to next_form and return if next_form.match(/Reception/i)
		  @relationships = @patient.relationships rescue []
		  @restricted = ProgramLocationRestriction.all(:conditions => {:location_id => Location.current_health_center.id })
		  @restricted.each do |restriction|
		    @relationships = restriction.filter_relationships(@relationships)
		  end
    	render :template => 'dashboards/relationships', :layout => 'dashboard' 
  	end
  end

  def problems
    render :template => 'dashboards/problems', :layout => 'dashboard' 
  end

  def personal
    @links = []
    patient = Patient.find(params[:id])

    @links << ["Demographics (Print)","/patients/print_demographics/#{patient.id}"]
    @links << ["Visit summary (Print)","/patients/dashboard_print_visit/#{patient.id}"]
    @links << ["National ID (Print)","/patients/dashboard_print_national_id/#{patient.id}"]

    if use_filing_number and not patient.get_identifier('Filing Number').blank?
      @links << ["Filing number (Print)","/patients/print_filing_number/#{patient.id}"]
    end 

    if use_filing_number and patient.get_identifier('Filing Number').blank?
      @links << ["Filing number (Create)","/patients/set_filing_number/#{patient.id}"]
    end 

    if GlobalProperty.use_user_selected_activities
      @links << ["Change user activities","/user/activities/#{User.current_user.id}?patient_id=#{patient.id}"]
    end

    @links << ["Recent Lab Orders Label","/patients/recent_lab_orders?patient_id=#{patient.id}"]

    render :template => 'dashboards/personal_tab', :layout => false
  end

  def history
    render :template => 'dashboards/history', :layout => 'dashboard' 
  end

  def programs
    @programs = @patient.patient_programs.all
    @restricted = ProgramLocationRestriction.all(:conditions => {:location_id => Location.current_health_center.id })
    @restricted.each do |restriction|
      @programs = restriction.filter_programs(@programs)
    end
    flash.now[:error] = params[:error] unless params[:error].blank?

    unless flash[:error].nil?
      redirect_to "/patients/programs_dashboard/#{@patient.id}?error=#{params[:error]}" and return
    else
      render :template => 'dashboards/programs_tab', :layout => false
    end
  end

  def graph
    @currentWeight = params[:currentWeight]
    render :template => "graphs/#{params[:data]}", :layout => false 
  end

  def void 
    @encounter = Encounter.find(params[:encounter_id])
    @encounter.void
    show and return
  end
  
  def print_registration
    print_and_redirect("/patients/national_id_label/?patient_id=#{@patient.id}", next_task(@patient))  
  end
  
  def dashboard_print_national_id
    unless params[:redirect].blank?
      redirect = "/#{params[:redirect]}/#{params[:id]}"
    else
      redirect = "/patients/show/#{params[:id]}"
    end
    print_and_redirect("/patients/national_id_label?patient_id=#{params[:id]}", redirect)  
  end
  
  def dashboard_print_visit
    print_and_redirect("/patients/visit_label/?patient_id=#{params[:id]}", "/patients/show/#{params[:id]}")
  end
  
  def print_visit
    print_and_redirect("/patients/visit_label/?patient_id=#{@patient.id}", next_task(@patient))  
  end
  
  def print_mastercard_record
    print_and_redirect("/patients/mastercard_record_label/?patient_id=#{@patient.id}&date=#{params[:date]}", "/patients/visit?date=#{params[:date]}&patient_id=#{params[:patient_id]}")  
  end
  
  def print_demographics
    print_and_redirect("/patients/patient_demographics_label/#{@patient.id}", "/patients/show/#{params[:id]}")
  end
 
  def print_filing_number
    print_and_redirect("/patients/filing_number_label/#{params[:id]}", "/patients/show/#{params[:id]}")  
  end
   
  def patient_demographics_label
    print_string = Patient.find(params[:id]).demographics_label 
    send_data(print_string,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{params[:id]}#{rand(10000)}.lbl", :disposition => "inline")
  end
  
  def national_id_label
    print_string = @patient.national_id_label rescue (raise "Unable to find patient (#{params[:patient_id]}) or generate a national id label for that patient")
    send_data(print_string,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{params[:patient_id]}#{rand(10000)}.lbl", :disposition => "inline")
  end

  def print_lab_orders
    print_and_redirect("/patients/lab_orders_label/?patient_id=#{@patient.id}", next_task(@patient))
  end

  def lab_orders_label
    patient = Patient.find(@patient.id)
    label_commands = patient.lab_orders_label
    send_data(label_commands.to_s,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{patient.id}#{rand(10000)}.lbl", :disposition => "inline")
  end

  def filing_number_label
    patient = Patient.find(params[:id])
    label_commands = patient.filing_number_label
    send_data(label_commands,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{patient.id}#{rand(10000)}.lbl", :disposition => "inline")
  end
 
  def filing_number_and_national_id
    patient = Patient.find(params[:patient_id])
    label_commands = patient.national_id_label + patient.filing_number_label

    send_data(label_commands,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{patient.id}#{rand(10000)}.lbl", :disposition => "inline")
  end
 
  def visit_label
    print_string = @patient.visit_label rescue (raise "Unable to find patient (#{params[:patient_id]}) or generate a visit label for that patient")
    send_data(print_string,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{params[:patient_id]}#{rand(10000)}.lbl", :disposition => "inline")
  end

  def mastercard_record_label
    print_string = @patient.visit_label(params[:date].to_date) 
    send_data(print_string,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{params[:patient_id]}#{rand(10000)}.lbl", :disposition => "inline")
  end

  def mastercard_menu
    render :layout => "menu"
    @patient_id = params[:patient_id]
  end

  def mastercard
    @type = params[:type]
    
    #the parameter are used to re-construct the url when the mastercard is called from a Data cleaning report
    @quarter = params[:quarter]
    @arv_start_number = params[:arv_start_number]
    @arv_end_number = params[:arv_end_number]
    @show_mastercard_counter = false
    
    if params[:patient_id].blank?

      @patient_id = session[:mastercard_ids][session[:mastercard_counter]]
       
    elsif session[:mastercard_ids].length.to_i != 0
      @patient_id = params[:patient_id]
    else
      @patient_id = params[:patient_id]
    end

    unless params.include?("source")
      @source = params[:source] rescue nil
    else
      @source = nil
    end

    render :layout => false
    
  end

  def mastercard_printable
    #the parameter are used to re-construct the url when the mastercard is called from a Data cleaning report
    @quarter = params[:quarter]
    @arv_start_number = params[:arv_start_number]
    @arv_end_number = params[:arv_end_number]
    @show_mastercard_counter = false

    if params[:patient_id].blank?

      @show_mastercard_counter = true

      if !params[:current].blank?
        session[:mastercard_counter] = params[:current].to_i - 1
      end
      @prev_button_class = "yellow"
      @next_button_class = "yellow"
      if params[:current].to_i ==  1
        @prev_button_class = "gray"
      elsif params[:current].to_i ==  session[:mastercard_ids].length
        @next_button_class = "gray"
      else

      end
      @patient_id = session[:mastercard_ids][session[:mastercard_counter]]
      @data_demo = Mastercard.demographics(Patient.find(@patient_id))
      @visits = Mastercard.visits(Patient.find(@patient_id))

      # elsif session[:mastercard_ids].length.to_i != 0
      #  @patient_id = params[:patient_id]
      #  @data_demo = Mastercard.demographics(Patient.find(@patient_id))
      #  @visits = Mastercard.visits(Patient.find(@patient_id))
    else
      @patient_id = params[:patient_id]
      @data_demo = Mastercard.demographics(Patient.find(@patient_id))
      @visits = Mastercard.visits(Patient.find(@patient_id))
    end
    render :layout => false
  end

  def visit
    @patient_id = params[:patient_id] 
    @date = params[:date].to_date
    @patient = Patient.find(@patient_id)
    @visits = Mastercard.visits(@patient,@date)
    render :layout => "menu"
  end

  def next_available_arv_number
    next_available_arv_number = PatientIdentifier.next_available_arv_number
    render :text => next_available_arv_number.gsub(PatientIdentifier.site_prefix,'').strip rescue nil
  end
  
  def assigned_arv_number
    assigned_arv_number = PatientIdentifier.find(:all,:conditions => ["voided = 0 AND identifier_type = ?",
        PatientIdentifierType.find_by_name("ARV Number").id]).collect{|i|
      i.identifier.gsub(PatientIdentifier.site_prefix,'').strip.to_i
    } rescue nil
    render :text => assigned_arv_number.sort.to_json rescue nil 
  end

  def mastercard_modify
    if request.method == :get
      @patient_id = params[:id]
      @patient = Patient.find(params[:id])
      @edit_page = Patient.edit_mastercard_attribute(params[:field].to_s)

      if @edit_page == "guardian"
        @guardian = {}
        @patient.person.relationships.map{|r| @guardian[Person.find(r.person_b).name] = Person.find(r.person_b).id.to_s;'' }
        if  @guardian == {}
          redirect_to :controller => "relationships" , :action => "search",:patient_id => @patient_id
        end
      end
    else
      @patient_id = params[:patient_id]
      Patient.save_mastercard_attribute(params)
      if params[:source].to_s == "opd"
        redirect_to "/patients/opdcard/#{@patient_id}" and return

      else
        redirect_to :action => "mastercard",:patient_id => @patient_id and return
      end
    end
  end

  def summary
    @encounter_type = params[:skipped]
    @patient_id = params[:patient_id]
    render :layout => "menu"
  end

  def set_filing_number
    patient = Patient.find(params[:id])
    patient.set_filing_number

    archived_patient = patient.patient_to_be_archived
    message = Patient.printing_message(patient,archived_patient,true)
    unless message.blank?
      print_and_redirect("/patients/filing_number_label/#{patient.id}" , "/patients/show/#{patient.id}",message,true,patient.id)
    else
      print_and_redirect("/patients/filing_number_label/#{patient.id}", "/patients/show/#{patient.id}")
    end
  end

  def set_new_filing_number
    patient = Patient.find(params[:id])
    patient.set_new_filing_number

    archived_patient = patient.patient_to_be_archived
    message = Patient.printing_message(patient,archived_patient)
    unless message.blank?
      print_and_redirect("/patients/filing_number_label/#{patient.id}" , "/people/confirm?found_person_id=#{patient.id}",message,true,patient.id)
    else
      print_and_redirect("/patients/filing_number_label/#{patient.id}", "/people/confirm?found_person_id=#{patient.id}")
    end
  end

  def export_to_csv
    ( Patient.find(:all,:limit => 10) || [] ).each do | patient |
      csv_string = FasterCSV.generate do |csv|
        # header row
        csv << ["ARV number", "National ID"]
        csv << [patient.arv_number, patient.national_id]
        csv << ["Name", "Age","Sex","Init Wt(Kg)","Init Ht(cm)","BMI","Transfer-in"]
        transfer_in = patient.person.observations.recent(1).question("HAS TRANSFER LETTER").all rescue nil
        transfer_in.blank? == true ? transfer_in = 'NO' : transfer_in = 'YES'
        csv << [patient.name,patient.person.age, patient.person.sex,patient.initial_weight,patient.initial_height,patient.initial_bmi,transfer_in]
        csv << ["Location", "Land-mark","Occupation","Init Wt(Kg)","Init Ht(cm)","BMI","Transfer-in"]

=begin
        # data rows
        @users.each do |user|
          csv << [user.id, user.username, user.salt]
        end
=end
      end
      # send it to the browsah
      send_data csv_string.gsub(' ','_'),
        :type => 'text/csv; charset=iso-8859-1; header=present',
        :disposition => "attachment:wq
              ; filename=patient-#{patient.id}.csv"
    end
  end

  def print_mastercard
    if @patient
      t1 = Thread.new{
        Kernel.system "htmldoc --webpage --landscape --linkstyle plain --left 1cm --right 1cm --top 1cm --bottom 1cm -f /tmp/output-" +
          session[:user_id].to_s + ".pdf http://" + request.env["HTTP_HOST"] + "\"/patients/mastercard_printable?patient_id=" +
          @patient.id.to_s + "\"\n"
      }

      t2 = Thread.new{
        sleep(5)
        Kernel.system "lpr /tmp/output-" + session[:user_id].to_s + ".pdf\n"
      }

      t3 = Thread.new{
        sleep(10)
        Kernel.system "rm /tmp/output-" + session[:user_id].to_s + ".pdf\n"
      }

    end

    redirect_to "/patients/mastercard?patient_id=#{@patient.id}" and return
  end
  
  def demographics
    render :layout => false
  end
   
  def index
    session[:mastercard_ids] = []
    session_date = session[:datetime].to_date rescue Date.today
    @encounters = @patient.encounters.find_by_date(session_date)
    @prescriptions = @patient.orders.unfinished.prescriptions.all
    @programs = @patient.patient_programs.all
    @alerts = @patient.alerts
    # This code is pretty hacky at the moment
    @restricted = ProgramLocationRestriction.all(:conditions => {:location_id => Location.current_health_center.id })
    @restricted.each do |restriction|
      @encounters = restriction.filter_encounters(@encounters)
      @prescriptions = restriction.filter_orders(@prescriptions)
      @programs = restriction.filter_programs(@programs)
    end

    @date = (session[:datetime].to_date rescue Date.today).strftime("%Y-%m-%d")

    render :template => 'patients/index', :layout => false
  end

  def overview
    session[:mastercard_ids] = []
    session_date = session[:datetime].to_date rescue Date.today
    @encounters = @patient.encounters.find_by_date(session_date)
    @prescriptions = @patient.orders.unfinished.prescriptions.all
    @programs = @patient.patient_programs.all
    @alerts = @patient.alerts
    # This code is pretty hacky at the moment
    @restricted = ProgramLocationRestriction.all(:conditions => {:location_id => Location.current_health_center.id })
    @restricted.each do |restriction|
      @encounters = restriction.filter_encounters(@encounters)
      @prescriptions = restriction.filter_orders(@prescriptions)
      @programs = restriction.filter_programs(@programs)
    end

    render :template => 'dashboards/overview_tab', :layout => false
  end

  def visit_history
    session[:mastercard_ids] = []
    session_date = session[:datetime].to_date rescue Date.today
    @encounters = @patient.encounters.find_by_date(session_date)
    @prescriptions = @patient.orders.unfinished.prescriptions.all
    @programs = @patient.patient_programs.all
    @alerts = @patient.alerts
    # This code is pretty hacky at the moment
    @restricted = ProgramLocationRestriction.all(:conditions => {:location_id => Location.current_health_center.id })
    @restricted.each do |restriction|
      @encounters = restriction.filter_encounters(@encounters)
      @prescriptions = restriction.filter_orders(@prescriptions)
      @programs = restriction.filter_programs(@programs)
    end

    render :template => 'dashboards/visit_history_tab', :layout => false
  end

  def past_visits_summary
    @previous_visits  = Encounter.get_previous_encounters(params[:patient_id])

    @encounter_dates = @previous_visits.map{|encounter| encounter.encounter_datetime.to_date}.uniq.reverse.first(6) rescue []

    @past_encounter_dates = []
      @encounter_dates.each do |encounter|
        @past_encounter_dates << encounter if encounter < (Date.today).to_date || encounter < (session[:datetime].to_date rescue Date.today.to_date)
      end

    render :template => 'dashboards/past_visits_summary_tab', :layout => false
  end

  def treatment_dashboard
    @amount_needed = 0
    @amounts_required = 0

    type = EncounterType.find_by_name('TREATMENT')
    session_date = session[:datetime].to_date rescue Date.today
    Order.find(:all,
      :joins => "INNER JOIN encounter e USING (encounter_id)",
      :conditions => ["encounter_type = ? AND e.patient_id = ? AND DATE(encounter_datetime) = ?",
        type.id,@patient.id,session_date]).each{|order|
      
      @amount_needed = @amount_needed + (order.drug_order.amount_needed.to_i rescue 0)

      @amounts_required = @amounts_required + (order.drug_order.total_required rescue 0)

    }

    @dispensed_order_id = params[:dispensed_order_id]
    render :template => 'dashboards/treatment_dashboard', :layout => false
  end

  def guardians_dashboard
    render :template => 'dashboards/relationships_dashboard', :layout => false
  end

  def programs_dashboard
    render :template => 'dashboards/programs_dashboard', :layout => false
  end

  def general_mastercard
    @type = nil
    
    case params[:type]
    when "1"
      @type = "yellow"
    when "2"
      @type = "green"
    when "3"
      @type = "pink"
    when "4"
      @type = "blue"
    end

    @mastercard = Mastercard.demographics(@patient)
    @visits = Mastercard.visits(@patient)   # (@patient, (session[:datetime].to_date rescue Date.today))

    render :layout => false
  end

  def patient_details
    render :layout => false
  end

  def status_details
    render :layout => false
  end

  def mastercard_details
    render :layout => false
  end

  def mastercard_header
    render :layout => false
  end

  def number_of_booked_patients
    date = params[:date].to_date
    encounter_type = EncounterType.find_by_name('APPOINTMENT')
    concept_id = ConceptName.find_by_name('APPOINTMENT DATE').concept_id
    count = Observation.count(:all,
            :joins => "INNER JOIN encounter e USING(encounter_id)",:group => "value_datetime",
            :conditions =>["concept_id = ? AND encounter_type = ? AND value_datetime >= ? AND value_datetime <= ?",
            concept_id,encounter_type.id,date.strftime('%Y-%m-%d 00:00:00'),date.strftime('%Y-%m-%d 23:59:59')])
    count = count.values unless count.blank?
    count = '0' if count.blank?
    render :text => count
  end

  def recent_lab_orders_print
    patient = Patient.find(params[:id])
    lab_orders_label = params[:lab_tests].split(":")

    label_commands = patient.recent_lab_orders_label(lab_orders_label)
    send_data(label_commands.to_s,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{patient.id}#{rand(10000)}.lbl", :disposition => "inline")
  end

  def print_recent_lab_orders_label
    #patient = Patient.find(params[:id])
    lab_orders_label = params[:lab_tests].join(":")

    #raise lab_orders_label.to_s
    #label_commands = patient.recent_lab_orders_label(lab_orders_label)
    #send_data(label_commands.to_s,:type=>"application/label; charset=utf-8", :stream=> false, :filename=>"#{patient.id}#{rand(10000)}.lbl", :disposition => "inline")

    print_and_redirect("/patients/recent_lab_orders_print/#{params[:id]}?lab_tests=#{lab_orders_label}" , "/patients/show/#{params[:id]}")
  end

  def recent_lab_orders
    patient = Patient.find(params[:patient_id])
    @lab_order_labels = patient.get_recent_lab_orders_label
    @patient_id = params[:patient_id]
  end
 
# AMU 5 Patient dashboard tabs 
  def tab_visit_summary
    @patient = Patient.find(params[:patient_id]  || params[:id] || session[:patient_id]) rescue nil
    @encounters = @patient.encounters.current.active rescue []
    @encounter_names = @patient.encounters.current.active.map{|encounter| encounter.name}.uniq rescue []

    render :layout => false
  end

  def tab_obstetric_history
    @patient = Patient.find(params[:patient_id]  || params[:id] || session[:patient_id]) rescue nil
    
    @deliveries = Observation.find(:last,
      :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?", @patient.id,
        Encounter.active.find(:all).collect{|e| e.encounter_id},
        ConceptName.find_by_name('PARITY').concept_id]).answer_string.to_i rescue 0

    @abortions = Observation.find(:last,
      :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?", @patient.id,
        Encounter.active.find(:all).collect{|e| e.encounter_id},
        ConceptName.find_by_name('NUMBER OF ABORTIONS').concept_id]).answer_string.to_i rescue 0

    @stillbirths = Observation.find(:last,
      :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?", @patient.id,
        Encounter.active.find(:all).collect{|e| e.encounter_id},
        ConceptName.find_by_name('STILL BIRTH').concept_id]).answer_string rescue nil

    @csections = Observation.find(:last,
      :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?", @patient.id,
        Encounter.active.find(:all).collect{|e| e.encounter_id},
        ConceptName.find_by_name('Caesarean section').concept_id]).answer_string rescue nil

    @vacuum = Observation.find(:last,
      :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?", @patient.id,
        Encounter.active.find(:all).collect{|e| e.encounter_id},
        ConceptName.find_by_name('Vacuum extraction delivery').concept_id]).answer_string rescue nil

    @symphosio = Observation.find(:last,
      :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?", @patient.id,
        Encounter.active.find(:all).collect{|e| e.encounter_id},
        ConceptName.find_by_name('SYMPHYSIOTOMY').concept_id]).answer_string rescue nil

    @haemorrhage = Observation.find(:last,
      :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?", @patient.id,
        Encounter.active.find(:all).collect{|e| e.encounter_id},
        ConceptName.find_by_name('HEMORRHAGE').concept_id]).answer_string rescue nil

    @preeclampsia = Observation.find(:last,
      :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?", @patient.id,
        Encounter.active.find(:all).collect{|e| e.encounter_id},
        ConceptName.find_by_name('PRE-ECLAMPSIA').concept_id]).answer_string rescue nil
    render :layout => false
  end

  def tab_medical_history
    @patient = Patient.find(params[:patient_id]  || params[:id] || session[:patient_id]) rescue nil
    
    @asthma = Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, Encounter.active.find(:all).collect{|e| e.encounter_id},
        ConceptName.find_by_name('ASTHMA').concept_id]).answer_string rescue nil

    @hyper = Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, Encounter.active.find(:all).collect{|e| e.encounter_id},
        ConceptName.find_by_name('HYPERTENSION').concept_id]).answer_string rescue nil

    @diabetes = Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, Encounter.active.find(:all).collect{|e| e.encounter_id},
        ConceptName.find_by_name('DIABETES').concept_id]).answer_string rescue nil

    @epilepsy = Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, Encounter.active.find(:all).collect{|e| e.encounter_id},
        ConceptName.find_by_name('EPILEPSY').concept_id]).answer_string rescue nil

    @renal = Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, Encounter.active.find(:all).collect{|e| e.encounter_id},
        ConceptName.find_by_name('RENAL DISEASE').concept_id]).answer_string rescue nil

    @fistula = Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, Encounter.active.find(:all).collect{|e| e.encounter_id},
        ConceptName.find_by_name('FISTULA REPAIR').concept_id]).answer_string rescue nil

    @deform = Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, Encounter.active.find(:all).collect{|e| e.encounter_id},
        ConceptName.find_by_name('SPINE OR LEG DEFORM').concept_id]).answer_string rescue nil

    @age = @patient.age rescue 0

    render :layout => false
  end

  def tab_examinations_management
    @patient = Patient.find(params[:patient_id]  || params[:id] || session[:patient_id]) rescue nil

    @height = @patient.current_height.to_i

    @multiple = Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, Encounter.active.find(:all).collect{|e| e.encounter_id},
        ConceptName.find_by_name('EVER HAD A MULTIPLE PREGNANCY?').concept_id]).answer_string rescue nil

    @who = Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, Encounter.active.find(:all).collect{|e| e.encounter_id},
        ConceptName.find_by_name('WHO CLINICAL STAGE').concept_id]).answer_string.to_i rescue nil

    render :layout => false
  end

  def tab_lab_results
    @patient = Patient.find(params[:patient_id]  || params[:id] || session[:patient_id]) rescue nil

    @syphilis = Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, Encounter.active.find(:all).collect{|e| e.encounter_id},
        ConceptName.find_by_name('SYPHILIS RESULT').concept_id]).answer_string rescue nil

    @syphilis_date = Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, Encounter.active.find(:all).collect{|e| e.encounter_id},
        ConceptName.find_by_name('SYPHILIS RESULT TEST DATE').concept_id]).answer_string rescue nil

    @hb1 = Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, Encounter.active.find(:all).collect{|e| e.encounter_id},
        ConceptName.find_by_name('HB 1 RESULT').concept_id]).answer_string rescue nil

    @hb1_date = Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, Encounter.active.find(:all).collect{|e| e.encounter_id},
        ConceptName.find_by_name('HB 1 RESULT TEST DATE').concept_id]).answer_string rescue nil

    @hb2 = Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, Encounter.active.find(:all).collect{|e| e.encounter_id},
        ConceptName.find_by_name('HB 2 RESULT').concept_id]).answer_string rescue nil

    @hb2_date = Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, Encounter.active.find(:all).collect{|e| e.encounter_id},
        ConceptName.find_by_name('HB 2 RESULT TEST DATE').concept_id]).answer_string rescue nil

    @cd4 = Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, Encounter.active.find(:all).collect{|e| e.encounter_id},
        ConceptName.find_by_name('CD4 COUNT').concept_id]).answer_string rescue nil

    @cd4_date = Observation.find(:last, :conditions => ["person_id = ? AND encounter_id IN (?) AND concept_id = ?",
        @patient.id, Encounter.active.find(:all).collect{|e| e.encounter_id},
        ConceptName.find_by_name('CD4 COUNT TEST DATE').concept_id]).answer_string rescue nil

    render :layout => false
  end

  def tab_visit_history
    @patient = Patient.find(params[:patient_id]  || params[:id] || session[:patient_id]) rescue nil

    @encounters = {}

    @patient.encounters.collect{|e| @encounters[e.encounter_datetime.strftime("%Y-%m-%d")] = {}}

    @patient.encounters.collect{|e| 
      @encounters[e.encounter_datetime.strftime("%Y-%m-%d")][e.type.name] = {}
    }

    @patient.encounters.collect{|e| 
      e.observations.each{|o| 
        @encounters[e.encounter_datetime.strftime("%Y-%m-%d")][e.type.name][o.to_a[0]] = o.to_a[1]
      }
    }

    # raise @encounters.to_yaml

    render :layout => false
  end


	#AMU 5 Encounters
	def current_visit
		@patient = Patient.find(params[:patient_id] || session[:patient_id])

		@encounters = @patient.encounters.active.find(:all, :conditions => ["encounter_type IN (?) AND " + 
			  "DATE_FORMAT(encounter_datetime, '%Y-%m-%d') = ?",
			EncounterType.find(:all, :conditions => ["name in ('OBSERVATIONS', 'VITALS', 'TREATMENT', 'LAB RESULTS', " +
				  "'DIAGNOSIS', 'APPOINTMENT')"]).collect{|t| t.id}, Date.today.strftime("%Y-%m-%d")]).collect{|e|
		  e.type.name
		}.join(", ") rescue ""
	    
	end 

	  def observations
		@patient = Patient.find(params[:patient_id]) rescue nil
	  end
end
