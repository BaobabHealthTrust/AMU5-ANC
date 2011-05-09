require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe PatientsController do
  integrate_views
  fixtures :patient, :patient_identifier, :users,
           :person, :person_name, :person_address,
           :encounter, :obs
  
  before(:each) do    
    session[:user_id] = users(:admin).id
  end
    
  before(:each) do
    @patient = Patient.find(patient(:Mary).patient_id)
  end
  
  it "should use PatientsController" do
    controller.should be_an_instance_of(PatientsController)
  end
  
  describe "GET 'show'" do
    it "should get show action" do
      get :show, {:patient_id => @patient.patient_id}
      response.should render_template("show")
    end
    
    it "should get patient id" do
      @patient = Patient.find(patient(:Mary).patient_id)
      @patient.should be_valid
    end
  end
  
  describe "GET 'tab_lab_results'" do
    it "should get the tab for lab results" do
      get :tab_lab_results
      response.should render_template("tab_lab_results")
    end
  end
  
  describe "GET 'tab_examinations_management'" do
    it "should get the tab for examinations management" do
      get :tab_examinations_management, {:patient_id => Patient.find(patient(:Mary).patient_id)}
      response.should render_template("tab_examinations_management")
    end
  end
  
  describe "GET 'tab_medical_history'" do
    it "should get the tab for medical history" do
      get :tab_medical_history
      response.should render_template("tab_medical_history")
    end
  end
  
  describe "GET 'tab_obstetric_history'" do
    it "should get the tab for obstetric history" do
      get :tab_obstetric_history
      response.should render_template("tab_obstetric_history")
    end
  end
  
  describe "GET 'tab_visit_summary'" do
    it "should get the tab for visit summary" do
      get :tab_visit_summary
      response.should render_template("tab_visit_summary")
    end
  end
  
  describe "GET 'observations'" do
    it "should get the observations action" do
      get :observations, {:patient_id => Patient.find(patient(:Mary).patient_id)}
      response.should render_template("observations")
    end
  end
  
  describe "GET 'preventative_medications'" do
    it "should get the preventative medications action" do
      get :preventative_medications, {:patient_id => Patient.find(patient(:Mary).patient_id)}
      response.should render_template("preventative_medications")
    end
  end
  
  describe "GET 'hiv_status'" do
    it "should get the hiv status action" do
      get :hiv_status, {:patient_id => Patient.find(patient(:Mary).patient_id)}
      response.should render_template("hiv_status")
    end
  end
  
  describe "GET 'pmtct_management'" do
    it "should get the pmtct management action" do
      get :pmtct_management, {:patient_id => Patient.find(patient(:Mary).patient_id)}
      response.should render_template("pmtct_management")
    end
  end
  
  describe "GET 'obstetric_history'" do
    it "should get the obstetric history action" do
      get :obstetric_history, {:patient_id => Patient.find(patient(:Mary).patient_id)}
      response.should render_template("obstetric_history")
    end
  end
  
  describe "GET 'medical_history'" do
    it "should get the medical history action" do
      get :medical_history, {:patient_id => Patient.find(patient(:Mary).patient_id)}
      response.should render_template("medical_history")
    end
  end
  
  describe "GET 'examinations_management'" do
    it "should get the examinations management action" do
      get :examination_management, {:patient_id => Patient.find(patient(:Mary).patient_id)}
      response.should render_template("examination_management")
    end
  end
  
  describe "GET 'lab_results'" do
    it "should get the lab results action" do
      get :lab_results, {:patient_id => Patient.find(patient(:Mary).patient_id)}
      response.should render_template("lab_results")
    end
  end
end

