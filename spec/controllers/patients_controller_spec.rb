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
    it "should show patient details" do
      get :show, {:patient_id => @patient.patient_id}
      response.should render_template("show")
    end

    it "should get the patient_id" do
      @patient = Patient.find(patient(:Mary).patient_id)
      @patient.should be_valid
    end
  end

  describe "GET 'tab_lab_results'" do
    it "should display patient's lab results" do
      get :tab_lab_results
      response.should render_template("tab_lab_results")
    end
  end

  describe "GET 'tab_examinations_management'" do
    it "should display patient's examinations management results" do
      get :tab_examinations_management, {:patient_id => Patient.find(patient(:Mary).patient_id)}
      response.should render_template("tab_examinations_management")
    end
  end

  describe "GET 'tab_medical_history'" do
    it "should display patient's medical history summary" do
      get :tab_medical_history
      response.should render_template("tab_medical_history")
    end
  end

  describe "GET 'tab_obstetric_history'" do
    it "should display patient's obstetric history summary" do
      get :tab_obstetric_history
      response.should render_template("tab_obstetric_history")
    end
  end

  describe "GET 'tab_visit_summary'" do
    it "should display patient's visit summary successfully" do
      get :tab_visit_summary
      response.should render_template("tab_visit_summary")
    end
  end

  describe "GET 'observations'" do
    it "should display patient's observations summary" do
      get :observations, {:patient_id => Patient.find(patient(:Mary).patient_id)}
      response.should render_template("observations")
    end
  end

  describe "GET 'preventative_medications'" do
    it "should display patient's preventative medications summary" do
      get :preventative_medications, {:patient_id => Patient.find(patient(:Mary).patient_id)}
      response.should render_template("preventative_medications")
    end
  end

  describe "GET 'hiv_status'" do
    it "should display patient's hiv status summary" do
      get :hiv_status, {:patient_id => Patient.find(patient(:Mary).patient_id)}
      response.should render_template("hiv_status")
    end
  end

  describe "GET 'pmtct_management'" do
    it "should display patient's pmtct management  action successfully" do
      get :pmtct_management, {:patient_id => Patient.find(patient(:Mary).patient_id)}
      response.should render_template("pmtct_management")
    end
  end

  describe "GET 'obstetric_history'" do
    it "should get the obstetric_history action successfully" do
      get :obstetric_history, {:patient_id => Patient.find(patient(:Mary).patient_id)}
      response.should render_template("obstetric_history")
    end
  end

  describe "GET 'medical_history'" do
    it "should get the medical_history action successfully" do
      get :medical_history, {:patient_id => Patient.find(patient(:Mary).patient_id)}
      response.should render_template("medical_history")
    end
  end

  describe "GET 'examinations_management'" do
    it "should get the examinations_management action successfully" do
      get :examination_management, {:patient_id => Patient.find(patient(:Mary).patient_id)}
      response.should render_template("examination_management")
    end
  end

  describe "GET 'lab_results'" do
    it "should get the lab_results action successfully" do
      get :lab_results, {:patient_id => Patient.find(patient(:Mary).patient_id)}
      response.should render_template("lab_results")
    end
  end
end
