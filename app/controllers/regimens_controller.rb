class RegimensController < ApplicationController
  def new
    @patient = Patient.find(params[:patient_id] || session[:patient_id]) rescue nil
    @programs = @patient.patient_programs.all
    @hiv_programs = @patient.patient_programs.not_completed.in_programs('HIV PROGRAM')
	
    @tb_programs = @patient.patient_programs.not_completed.in_programs('TB PROGRAM')

    @current_regimens_for_programs = current_regimens_for_programs
    @current_regimen_names_for_programs = current_regimen_names_for_programs

	@prescribe_tb_drugs = true	
	if @tb_programs.blank?
		@prescribe_tb_drugs = false
	end

	#raise @prescribe_tb_drugs.to_s
	#raise @tb_programs.to_yaml
		
  end
  
  def create
   prescribe_tb_drugs = false   
	prescribe_arvs = false
   prescribe_cpt = false
   prescribe_ipt = false

   (params[:observations] || []).each do |observation|
      if observation['concept_name'].upcase == 'PRESCRIBE DRUGS'
        prescribe_tb_drugs = ('YES' == observation['value_coded_or_text'])
	  elsif observation['concept_name'] == 'PRESCRIBE ARVS'
        prescribe_arvs = ('YES' == observation['value_coded_or_text'])
      elsif observation['concept_name'] == 'Prescribe cotramoxazole'
        prescribe_cpt = ('YES' == observation['value_coded_or_text'])
      elsif observation['concept_name'] == 'ISONIAZID'
        prescribe_ipt = ('YES' == observation['value_coded_or_text'])
      end
    end
    @patient = Patient.find(params[:patient_id] || session[:patient_id]) rescue nil
    session_date = session[:datetime] || Time.now()
    encounter = @patient.current_treatment_encounter(session_date)
    start_date = session[:datetime] || Time.now
    auto_expire_date = session[:datetime] + params[:duration].to_i.days rescue Time.now + params[:duration].to_i.days
    auto_tb_expire_date = session[:datetime] + params[:tb_duration].to_i.days rescue Time.now + params[:tb_duration].to_i.days

    orders = RegimenDrugOrder.all(:conditions => {:regimen_id => params[:regimen]})
    ActiveRecord::Base.transaction do
      # Need to write an obs for the regimen they are on, note that this is ARV
      # Specific at the moment and will likely need to have some kind of lookup
      # or be made generic
      obs = Observation.create(
        :concept_name => "WHAT TYPE OF ANTIRETROVIRAL REGIMEN",
        :person_id => @patient.person.person_id,
        :encounter_id => encounter.encounter_id,
        :value_coded => params[:regimen_concept_id],
        :obs_datetime => start_date) if prescribe_arvs
      orders.each do |order|
        drug = Drug.find(order.drug_inventory_id)
        regimen_name = (order.regimen.concept.concept_names.typed("SHORT").first || order.regimen.concept.name).name
        DrugOrder.write_order(
          encounter, 
          @patient, 
          obs, 
          drug, 
          start_date, 
          auto_expire_date, 
          order.dose, 
          order.frequency, 
          order.prn, 
          "#{drug.name}: #{order.instructions} (#{regimen_name})",
          order.equivalent_daily_dose)    
      end if prescribe_arvs
    end

	orders = RegimenDrugOrder.all(:conditions => {:regimen_id => params[:tb_regimen]})
    ActiveRecord::Base.transaction do
      # Need to write an obs for the regimen they are on, note that this is ARV
      # Specific at the moment and will likely need to have some kind of lookup
      # or be made generic
      obs = Observation.create(
        :concept_name => "WHAT TYPE OF ANTIRETROVIRAL REGIMEN",
        :person_id => @patient.person.person_id,
        :encounter_id => encounter.encounter_id,
        :value_coded => params[:tb_regimen_concept_id],
        :obs_datetime => start_date) if prescribe_tb_drugs
      orders.each do |order|
        drug = Drug.find(order.drug_inventory_id)
        regimen_name = (order.regimen.concept.concept_names.typed("SHORT").first || order.regimen.concept.name).name
        DrugOrder.write_order(
          encounter, 
          @patient, 
          obs, 
          drug, 
          start_date, 
          auto_tb_expire_date, 
          order.dose, 
          order.frequency, 
          order.prn, 
          "#{drug.name}: #{order.instructions} (#{regimen_name})",
          order.equivalent_daily_dose)  
      end if prescribe_tb_drugs
    end

    
    ['CPT STARTED','ISONIAZID'].each do | concept_name |
      if concept_name == 'ISONIAZID'
        concept = 'NO' unless prescribe_ipt
        concept = 'YES' if prescribe_ipt
      else
        concept = 'NO' unless prescribe_cpt
        concept = 'YES' if prescribe_cpt
      end
      yes_no = ConceptName.find_by_name(concept)
      obs = Observation.create(
        :concept_name => concept_name ,
        :person_id => @patient.person.person_id ,
        :encounter_id => encounter.encounter_id ,
        :value_coded => yes_no.concept_id ,
        :obs_datetime => start_date) 

      next if concept == 'NO'

      if concept_name == 'CPT STARTED'
        drug = Drug.find_by_name('Cotrimoxazole (480mg tablet)')
      else
        drug = Drug.find_by_name('INH or H (Isoniazid 100mg tablet)')
      end

      orders = RegimenDrugOrder.all(:conditions => {:regimen_id => Regimen.find_by_concept_id(drug.concept_id).regimen_id})
      orders.each do |order|
        drug = Drug.find(order.drug_inventory_id)
        regimen_name = (order.regimen.concept.concept_names.typed("SHORT").first || order.regimen.concept_names.typed("FULLY_SPECIFIED").first).name
        DrugOrder.write_order(
          encounter, 
          @patient, 
          obs, 
          drug, 
          start_date, 
          auto_expire_date, 
          order.dose, 
          order.frequency, 
          order.prn, 
          "#{drug.name}: #{order.instructions} (#{regimen_name})",
          order.equivalent_daily_dose)    
      end
    end
		 
    # Send them back to treatment for now, eventually may want to go to workflow
    redirect_to "/patients/treatment_dashboard?patient_id=#{@patient.id}"
  end    

  def suggested
    patient_program = PatientProgram.find(params[:id])
    @options = []
    render :layout => false and return unless patient_program

    regimen_concepts = patient_program.regimens(patient_program.patient.current_weight).uniq
    @options = regimen_options(regimen_concepts, params[:patient_age].to_i)

    render :layout => false
  end

  def dosing
    @patient = Patient.find(params[:patient_id] || session[:patient_id]) rescue nil
    @criteria = Regimen.criteria(@patient.current_weight).all(:conditions => {:concept_id => params[:id]}, :include => :regimen_drug_orders)
    @options = @criteria.map do |r| 
      [r.regimen_id, r.regimen_drug_orders.map(&:to_s).join('; ')]
    end
    render :layout => false    
  end
  
  def formulations
    @patient = Patient.find(params[:patient_id] || session[:patient_id]) rescue nil
    @criteria = Regimen.criteria(@patient.current_weight).all(:conditions => {:concept_id => params[:id]}, :include => :regimen_drug_orders)
    @options = @criteria.map do | r | 
      r.regimen_drug_orders.map do | order |
        [order.drug.name , order.dose, order.frequency , order.units , r.id ]
      end
    end
    render :text => @options.to_json    
  end

  # Look up likely durations for the regimen
  def durations
    @regimen = Regimen.find_by_concept_id(params[:id], :include => :regimen_drug_orders)
    @drug_id = @regimen.regimen_drug_orders.first.drug_inventory_id rescue nil
    render :text => "No matching durations found for regimen" and return unless @drug_id

    # Grab the 10 most popular durations for this drug
    amounts = []
    orders = DrugOrder.find(:all, 
      :select => 'DATEDIFF(orders.auto_expire_date, orders.start_date) as duration_days',
      :joins => 'LEFT JOIN orders ON orders.order_id = drug_order.order_id AND orders.voided = 0',
      :limit => 10, 
      :group => 'drug_inventory_id, DATEDIFF(orders.auto_expire_date, orders.start_date)', 
      :order => 'count(*)', 
      :conditions => {:drug_inventory_id => @drug_id})      
    orders.each {|order|
      amounts << "#{order.duration_days.to_f}" unless order.duration_days.blank?
    }  
    amounts = amounts.flatten.compact.uniq
    render :text => "<li>" + amounts.join("</li><li>") + "</li>"
  end
  
  private
  
  def current_regimens_for_programs
    @programs.inject({}) do |result, program| 
      result[program.patient_program_id] = program.current_regimen; result 
    end
  end

  def current_regimen_names_for_programs
    @programs.inject({}) do |result, program| 
    
      result[program.patient_program_id] = program.current_regimen ? Concept.find_by_concept_id(program.current_regimen).concept_names.tagged(["short"]).map(&:name) : nil; result 
    end
  end

private

  
end
