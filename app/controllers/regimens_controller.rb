class RegimensController < ApplicationController

	def new
		@patient = Patient.find(params[:patient_id] || session[:patient_id]) rescue nil
		@programs = @patient.patient_programs.all
		@hiv_programs = @patient.patient_programs.not_completed.in_programs('HIV PROGRAM')
    	
		@tb_encounter = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
                    :conditions=>["patient_id = ? AND encounter_type = ?", 
                    @patient.id, EncounterType.find_by_name("TB visit").id], 
                    :include => [:observations]) rescue nil

		@tb_programs = @patient.patient_programs.in_uncompleted_programs(['TB PROGRAM', 'MDR-TB PROGRAM'])
		
		@current_regimens_for_programs = current_regimens_for_programs
		@current_regimen_names_for_programs = current_regimen_names_for_programs

		session_date = session[:datetime].to_date rescue Date.today

		pre_art_visit = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
		    :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
		    session_date.to_date, @patient.id, EncounterType.find_by_name('PART_FOLLOWUP').id])

		art_visit = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
            :conditions =>["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
            session_date.to_date, @patient.id, EncounterType.find_by_name('ART VISIT').id])
		@art_visit = false

		if ((not pre_art_visit.blank?) or (not art_visit.blank?))
			@art_visit = true		
		end

		treatment_obs = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
		    :conditions => ["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
		    session_date, @patient.id, EncounterType.find_by_name('TREATMENT').id]).observations rescue []

		tb_medication_prescribed = false
		arvs_prescribed = false
		(treatment_obs || []).each do | obs | 
			if obs.concept_id == (Concept.find_by_name('TB regimen type').concept_id rescue nil)
				tb_medication_prescribed = true 
			end

			if obs.concept_id == (Concept.find_by_name('ARV regimen type').concept_id rescue nil)
				arvs_prescribed = true 
			end
		end

		tb_visit_obs = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
		    :conditions => ["DATE(encounter_datetime) = ? AND patient_id = ? AND encounter_type = ?",
		    session_date, @patient.id, EncounterType.find_by_name('TB VISIT').id]).observations rescue []

		prescribe_tb_medication = false
		@transfer_out_patient = false;
		(tb_visit_obs || []).each do | obs | 
			if obs.concept_id == (Concept.find_by_name('Prescribe drugs').concept_id rescue nil)
				prescribe_tb_medication = true if Concept.find(obs.value_coded).fullname.upcase == 'YES' 
			end

			if obs.concept_id == (Concept.find_by_name('Continue treatment').concept_id rescue nil)
				@transfer_out_patient = true if Concept.find(obs.value_coded).fullname.upcase == 'NO' 
			end
		end
		
		@prescribe_tb_drugs = false	
		if (not @tb_programs.blank?) and prescribe_tb_medication and !tb_medication_prescribed
			@prescribe_tb_drugs = true
		end

		sulphur_allergy_obs = Encounter.find(:first,:order => "encounter_datetime DESC,date_created DESC",
			:conditions => ["patient_id = ? AND encounter_type IN (?) AND DATE(encounter_datetime) = ?",
			@patient.id, EncounterType.find(:all,:select => 'encounter_type_id', 
      :conditions => ["name IN (?)",["ART VISIT", "TB VISIT"]]),session_date.to_date]).observations rescue []

		@alergic_to_suphur = false
		(sulphur_allergy_obs || []).each do | obs |
			if obs.concept_id == (Concept.find_by_name('sulphur allergy').concept_id rescue nil)
				@alergic_to_suphur = true if Concept.find(obs.value_coded).fullname.upcase == 'YES'
			end
		end

		art_visit_obs = Encounter.find(:first,
      :order => "encounter_datetime DESC,date_created DESC",
			:conditions => ["patient_id = ? AND encounter_type IN (?) AND DATE(encounter_datetime) = ?",
			@patient.id, EncounterType.find(:all,:select => 'encounter_type_id', 
      :conditions => ["name IN (?)",["ART VISIT"]]),session_date.to_date]).observations rescue []

		@prescribe_art_drugs = false
		(art_visit_obs || []).each do | obs |
			if obs.concept_id == (Concept.find_by_name('Prescribe arvs').concept_id rescue nil)
				@prescribe_art_drugs = true if Concept.find(obs.value_coded).fullname.upcase == 'YES' and !arvs_prescribed
			end
		end

	    session_date = session[:datetime].to_date rescue Date.today
        current_encounters = @patient.encounters.find_by_date(session_date)
        @family_planning_methods = []
        @is_patient_pregnant_value = 'Unknown'

        for encounter in current_encounters.reverse do

            if encounter.name.humanize.include?('Hiv staging') || encounter.name.humanize.include?('Tb visit') || encounter.name.humanize.include?('Art visit') 
             
                encounter = Encounter.find(encounter.id, :include => [:observations])

                for obs in encounter.observations do
                    if obs.concept_id == ConceptName.find_by_name("IS PATIENT PREGNANT?").concept_id
                        @is_patient_pregnant_value = "#{obs.to_s(["short", "order"]).to_s.split(":")[1]}"
                    end                    
                end

                if encounter.name.humanize.include?('Tb visit') || encounter.name.humanize.include?('Art visit')

                    encounter = Encounter.find(encounter.id, :include => [:observations])
                    for obs in encounter.observations do
                        if obs.concept_id == ConceptName.find_by_name("CURRENTLY USING FAMILY PLANNING METHOD").concept_id
                            @currently_using_family_planning_methods = "#{obs.to_s(["short", "order"]).to_s.split(":")[1]}".squish
                        end

                        if obs.concept_id == ConceptName.find_by_name("FAMILY PLANNING METHOD").concept_id
                            @family_planning_methods << "#{obs.to_s(["short", "order"]).to_s.split(":")[1]}".squish.humanize
                        end
                    end
                    
                end
                
            end
        end
		


	end
  
	def create

		prescribe_tb_drugs = false   
		prescribe_tb_continuation_drugs = false   
		prescribe_arvs = false
		prescribe_cpt = false
		prescribe_ipt = false
		clinical_notes = nil
		condoms = nil
		(params[:observations] || []).each do |observation|
			if observation['concept_name'].upcase == 'PRESCRIBE DRUGS'
				prescribe_tb_drugs = ('YES' == observation['value_coded_or_text'])
				prescribe_tb_continuation_drugs = ('YES' == observation['value_coded_or_text'])
			elsif observation['concept_name'] == 'PRESCRIBE ARVS'
				prescribe_arvs = ('YES' == observation['value_coded_or_text'])
			elsif observation['concept_name'] == 'Prescribe cotramoxazole'
				prescribe_cpt = ('YES' == observation['value_coded_or_text'])
			elsif observation['concept_name'] == 'ISONIAZID'
				prescribe_ipt = ('YES' == observation['value_coded_or_text'])
			elsif observation['concept_name'] == 'CLINICAL NOTES CONSTRUCT'
				clinical_notes = observation['value_text']
			elsif observation['concept_name'] == 'CONDOMS'
				condoms = observation['value_numeric']
			end
		end
		@patient = Patient.find(params[:patient_id] || session[:patient_id]) rescue nil
		session_date = session[:datetime] || Time.now()
		encounter = @patient.current_treatment_encounter(session_date)
		start_date = session[:datetime] || Time.now
		auto_expire_date = session[:datetime] + params[:duration].to_i.days rescue Time.now + params[:duration].to_i.days
		auto_tb_expire_date = session[:datetime] + params[:tb_duration].to_i.days rescue Time.now + params[:tb_duration].to_i.days
		auto_tb_continuation_expire_date = session[:datetime] + params[:tb_continuation_duration].to_i.days rescue Time.now + params[:tb_continuation_duration].to_i.days
		auto_cpt_ipt_expire_date = session[:datetime] + params[:duration].to_i.days rescue Time.now + params[:duration].to_i.days

		orders = RegimenDrugOrder.all(:conditions => {:regimen_id => params[:tb_regimen]})
		ActiveRecord::Base.transaction do
			# Need to write an obs for the regimen they are on, note that this is ARV
			# Specific at the moment and will likely need to have some kind of lookup
			# or be made generic
			obs = Observation.create(
				:concept_name => "WHAT TYPE OF TUBERCULOSIS REGIMEN",
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

		orders = RegimenDrugOrder.all(:conditions => {:regimen_id => params[:tb_continuation_regimen]})
		ActiveRecord::Base.transaction do
			# Need to write an obs for the regimen they are on, note that this is ARV
			# Specific at the moment and will likely need to have some kind of lookup
			# or be made generic
			obs = Observation.create(
				:concept_name => "WHAT TYPE OF TUBERCULOSIS REGIMEN",
				:person_id => @patient.person.person_id,
				:encounter_id => encounter.encounter_id,
				:value_coded => params[:tb_continuation_regimen_concept_id],
				:obs_datetime => start_date) if prescribe_tb_continuation_drugs
			orders.each do |order|
				drug = Drug.find(order.drug_inventory_id)
				regimen_name = (order.regimen.concept.concept_names.typed("SHORT").first || order.regimen.concept.name).name
				DrugOrder.write_order(
					encounter, 
					@patient, 
					obs, 
					drug, 
					start_date, 
					auto_tb_continuation_expire_date, 
					order.dose, 
					order.frequency, 
					order.prn, 
					"#{drug.name}: #{order.instructions} (#{regimen_name})",
					order.equivalent_daily_dose)  
			end if prescribe_tb_continuation_drugs
		end

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
				auto_cpt_ipt_expire_date, 
				order.dose, 
				order.frequency, 
				order.prn, 
				"#{drug.name}: #{order.instructions} (#{regimen_name})",
				order.equivalent_daily_dose)    
			end
		end
   
		obs = Observation.create(
			:concept_name => "CLINICAL NOTES CONSTRUCT",
			:person_id => @patient.person.person_id,
			:encounter_id => encounter.encounter_id,
			:value_text => clinical_notes,
			:obs_datetime => start_date) if !clinical_notes.blank?

		obs = Observation.create(
			:concept_name => "CONDOMS",
			:person_id => @patient.person.person_id,
			:encounter_id => encounter.encounter_id,
			:value_numeric => condoms,
			:obs_datetime => start_date) if !condoms.blank?
		
		if !params[:transfer_data].nil?
			transfer_out_patient(params[:transfer_data][0])
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
		#raise @options.to_yaml
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
	
def transfer_out_patient(params)
    
    patient_program = PatientProgram.find(params[:patient_program_id])
    

    
    #we don't want to have more than one open states - so we have to close the current active on before opening/creating a new one

    current_active_state = patient_program.patient_states.last
    current_active_state.end_date = params[:current_date].to_date


     # set current location via params if given
    Location.current_location = Location.find(params[:location]) if params[:location]

    patient_state = patient_program.patient_states.build( :state => params[:current_state], :start_date => params[:current_date])


    if patient_state.save
      #Close and save current_active_state if a new state has been created
      current_active_state.save

      if patient_state.program_workflow_state.concept.fullname.upcase == 'PATIENT TRANSFERRED OUT'
      
        encounter = Encounter.new(params[:encounter])
        encounter.encounter_datetime = session[:datetime] unless session[:datetime].blank?
        c = encounter.save

        (params[:observations] || [] ).each do |observation|
          #for now i do this
          obs = {}
          obs[:concept_name] = observation[:concept_name] 
          obs[:value_coded_or_text] = observation[:value_coded_or_text] 
          obs[:encounter_id] = encounter.id
          obs[:obs_datetime] = encounter.encounter_datetime || Time.now()
          obs[:person_id] ||= encounter.patient_id  
          Observation.create(obs)
        end

        observation = {} 
        observation[:concept_name] = 'TRANSFER OUT TO'
        observation[:encounter_id] = encounter.id
        observation[:obs_datetime] = encounter.encounter_datetime || Time.now()
        observation[:person_id] ||= encounter.patient_id
        observation[:value_text] = Location.find(params[:transfer_out_location_id]).name rescue "UNKNOWN"
        Observation.create(observation)
      end

      date_completed = params[:current_date].to_date rescue Time.now()
      
      PatientProgram.update_all "date_completed = '#{date_completed.strftime('%Y-%m-%d %H:%M:%S')}'",
                                 "patient_program_id = #{patient_program.patient_program_id}"
    end
end

end
