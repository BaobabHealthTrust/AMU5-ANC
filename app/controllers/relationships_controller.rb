class RelationshipsController < ApplicationController
  before_filter :find_patient, :except => [:void]
  
  def new
    #raise'new'
    render :layout => 'application'
    # render :template => 'dashboards/relationships_dashboard', :layout => false
  end

  def search
    session[:return_to] = nil
    session[:return_to] = params[:return_to] unless params[:return_to].blank?
    session[:guardian_added] = nil
    session[:guardian_added] = params[:guardian_added] unless params[:guardian_added].blank?
    render :layout => 'relationships'
  end

  def create
    relationship_id = params[:relationship].to_i rescue nil
    if relationship_id == RelationshipType.find_by_b_is_to_a('TB Index Person').id
      person_id = params[:person].to_i
      if person_id == 0 #if the person does not exist in db
        person = Person.create_from_form({'names' => 
                                           {'family_name' => params[:family_name],
                                            'given_name' => params[:given_name]
                                         },'gender' => params[:gender]
                                        } 
                                        )

        person_id = person.id
      end
      @relationship = Relationship.new(
        :person_a => @patient.patient_id,
        :person_b => params[:relation],
        :relationship => params[:relationship])
      if @relationship.save
        redirect_to session[:return_to] and return unless session[:return_to].blank?
        redirect_to :controller => :patients, :action => :guardians_dashboard, :patient_id => @patient.patient_id
      else
        render :action => "new"
      end

    else

      @relationship = Relationship.new(
        :person_a => @patient.patient_id,
        :person_b => params[:relation],
        :relationship => params[:relationship])
      if @relationship.save
        redirect_to session[:return_to] and return unless session[:return_to].blank?
        redirect_to :controller => :patients, :action => :guardians_dashboard, :patient_id => @patient.patient_id
      else 
        render :action => "new" 
      end
   end
  end

  def void
    @relationship = Relationship.find(params[:id])
    @relationship.void
    head :ok
  end  
end
