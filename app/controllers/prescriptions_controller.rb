class PrescriptionsController < ApplicationController
  # Is this used?
  def index
    @patient = Patient.find(params[:patient_id] || session[:patient_id]) rescue nil
    @orders = @patient.orders.prescriptions.current.all rescue []
    @history = @patient.orders.prescriptions.historical.all rescue []
    redirect_to "/prescriptions/new?patient_id=#{params[:patient_id] || session[:patient_id]}" and return if @orders.blank?
    render :template => 'prescriptions/index', :layout => 'menu'
  end
  
  def new
    @patient = Patient.find(params[:patient_id] || session[:patient_id]) rescue nil
  end
  
  def void 
    @order = Order.find(params[:order_id])
    @order.void
    flash.now[:notice] = "Order was successfully voided"
    index and return
  end
  
  def create
    # raise params.to_yaml

    encounter = Encounter.new(params[:encounter])
    encounter.encounter_datetime ||= session[:datetime]
    encounter.save

    (params[:prescriptions] || []).each{|prescription|
      @patient    = Patient.find(prescription[:patient_id] || session[:patient_id]) rescue nil
      @encounter  = encounter

      diagnosis_name = prescription[:value_coded_or_text]

      values = "coded_or_text group_id boolean coded drug datetime numeric modifier text".split(" ").map{|value_name|
        prescription["value_#{value_name}"] unless prescription["value_#{value_name}"].blank? rescue nil
      }.compact

      next if values.length == 0
      prescription.delete(:value_text) unless prescription[:value_coded_or_text].blank?

      prescription[:encounter_id]  = @encounter.encounter_id
      prescription[:obs_datetime]  = @encounter.encounter_datetime ||= (session[:datetime] ||=  Time.now())
      prescription[:person_id]     = @encounter.patient_id

      diagnosis_observation = Observation.create("encounter_id" => prescription[:encounter_id],
        "concept_name" => "DIAGNOSIS",
        "obs_datetime" => prescription[:obs_datetime],
        "person_id" => prescription[:person_id],
        "value_coded_or_text" => diagnosis_name)

      prescription[:diagnosis] = diagnosis_observation.id

      @diagnosis = Observation.find(prescription[:diagnosis]) rescue nil

      prescription[:dosage] =  "" unless !prescription[:dosage].nil?

      prescription[:formulation] = [prescription[:drug],
        prescription[:dosage],
        prescription[:frequency],
        prescription[:strength],
        prescription[:units]]

      drug_info = prescription[:dosage].scan(/(\d+)(\w+)?/)

      drug_info[0] << ConceptName.find_by_name(prescription[:drug], :joins => :concept,
        :conditions => ["retired = 0"]).concept_id rescue nil

      @drug = Drug.find(:last, :conditions => ["concept_id = ? AND COALESCE(dose_strength, 0) = " +
            " ? AND COALESCE(units, '') LIKE ?", drug_info[0][2],
          (drug_info[0][0].nil? ? "" : drug_info[0][0]),
          (drug_info[0][1].nil? ? "" : drug_info[0][1]) + "%"]) rescue nil

      # raise @drug.to_yaml

      unless @drug
        flash[:notice] = "No matching drugs found for formulation #{prescription[:formulation]}"
        @patient = Patient.find(prescription[:patient_id] || session[:patient_id]) rescue nil
        @generics = Drug.generic
        @frequencies = Drug.frequencies
        @diagnosis = @patient.current_diagnoses["DIAGNOSIS"] rescue []

        render :give_drugs
        return
      end

      start_date = session[:datetime] ||=  Time.now
      auto_expire_date = (session[:datetime] ||=  Time.now) + prescription[:duration].to_i.days

      DrugOrder.write_order(@encounter, @patient, @diagnosis, @drug, start_date,
        auto_expire_date, prescription[:dosage], prescription[:frequency], 0, 1)

    }

    redirect_to ("/patients/current_visit/?patient_id=#{@patient.id}")
  end
  
  def auto
    @patient = Patient.find(params[:patient_id] || session[:patient_id]) rescue nil
    # Find the next diagnosis that doesn't have a corresponding order
    @diagnoses = @patient.current_diagnoses
    @prescriptions = @patient.orders.current.prescriptions.all.map(&:obs_id).uniq
    @diagnoses = @diagnoses.reject {|diag| @prescriptions.include?(diag.obs_id) }
    if @diagnoses.empty?
      redirect_to "/prescriptions/new?patient_id=#{@patient.id}"
    else
      redirect_to "/prescriptions/new?patient_id=#{@patient.id}&diagnosis=#{@diagnoses.first.obs_id}&auto=#{@diagnoses.length == 1 ? 0 : 1}"
    end  
  end
  
  # Look up the set of matching generic drugs based on the concepts. We 
  # limit the list to only the list of drugs that are actually in the 
  # drug list so we don't pick something we don't have.
  def generics
    search_string = (params[:search_string] || '').upcase
    filter_list = params[:filter_list].split(/, */) rescue []    
    @drug_concepts = ConceptName.find(:all, 
      :select => "concept_name.name", 
      :joins => "INNER JOIN drug ON drug.concept_id = concept_name.concept_id AND drug.retired = 0", 
      :conditions => ["concept_name.name LIKE ?", '%' + search_string + '%'],:group => 'drug.concept_id')
    render :text => "<li>" + @drug_concepts.map{|drug_concept| drug_concept.name }.uniq.join("</li><li>") + "</li>"
  end
  
  # Look up all of the matching drugs for the given generic drugs
  def formulations
    @generic = (params[:generic] || '')
    @concept_ids = ConceptName.find_all_by_name(@generic).map{|c| c.concept_id}
    render :text => "" and return if @concept_ids.blank?
    search_string = (params[:search_string] || '').upcase
    @drugs = Drug.find(:all, 
      :select => "name", 
      :conditions => ["concept_id IN (?) AND name LIKE ?", @concept_ids, '%' + search_string + '%'])
    render :text => "<li>" + @drugs.map{|drug| drug.name }.join("</li><li>") + "</li>"
  end
  
  # Look up likely durations for the drug
  def durations
    @formulation = (params[:formulation] || '').upcase
    drug = Drug.find_by_name(@formulation) rescue nil
    render :text => "No matching drugs found for #{params[:formulation]}" and return unless drug

    # Grab the 10 most popular durations for this drug
    amounts = []
    orders = DrugOrder.find(:all, 
      :select => 'DATEDIFF(orders.auto_expire_date, orders.start_date) as duration_days',
      :joins => 'LEFT JOIN orders ON orders.order_id = drug_order.order_id AND orders.voided = 0',
      :limit => 10, 
      :group => 'drug_inventory_id, DATEDIFF(orders.auto_expire_date, orders.start_date)', 
      :order => 'count(*)', 
      :conditions => {:drug_inventory_id => drug.id})
      
    orders.each {|order|
      amounts << "#{order.duration_days.to_f}" unless order.duration_days.blank?
    }  
    amounts = amounts.flatten.compact.uniq
    render :text => "<li>" + amounts.join("</li><li>") + "</li>"
  end

  # Look up likely dose_strength for the drug
  def dosages
    @formulation = (params[:formulation] || '')
    drug = Drug.find_by_name(@formulation) rescue nil
    render :text => "No matching drugs found for #{params[:formulation]}" and return unless drug

    @frequency = (params[:frequency] || '')

    # Grab the 10 most popular dosages for this drug
    amounts = []
    amounts << "#{drug.dose_strength}" if drug.dose_strength 
    orders = DrugOrder.find(:all, 
      :limit => 10, 
      :group => 'drug_inventory_id, dose', 
      :order => 'count(*)', 
      :conditions => {:drug_inventory_id => drug.id, :frequency => @frequency})
    orders.each {|order|
      amounts << "#{order.dose}"
    }.uniq.flatten.compact
    
    amounts = amounts.uniq.flatten.compact
    render :text => "<li>" + amounts.join("</li><li>") + "</li>"
  end

  # Look up the units for the first substance in the drug, ideally we should re-activate the units on drug for aggregate units
  def units
    @formulation = (params[:formulation] || '').upcase
    drug = Drug.find_by_name(@formulation) rescue nil
    render :text => "per dose" and return unless drug && !drug.units.blank?
    render :text => drug.units
  end
  
  def suggested
    @diagnosis = Observation.find(params[:diagnosis]) rescue nil
    @options = []
    render :layout => false and return unless @diagnosis && @diagnosis.value_coded
    @orders = DrugOrder.find_common_orders(@diagnosis.value_coded)
    @options = @orders.map{|o| [o.order_id, o.script] } + @options
    render :layout => false
  end

  def give_drugs
    @patient = Patient.find(params[:patient_id] || session[:patient_id]) rescue nil
    @generics = Drug.generic
    @frequencies = Drug.frequencies
    @diagnosis = @patient.current_diagnoses["DIAGNOSIS"] rescue []
  end

  def load_frequencies_and_dosages
    @drugs = Drug.drugs(params[:concept_id]).to_json
    render :text => @drugs
  end
  
end
