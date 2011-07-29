require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe PatientsController do
  integrate_views
  fixtures :patient, :patient_identifier, :patient_identifier_type,
           :users, :person, :person_name, :person_address,
           :encounter, :obs, :concept_name

  set_fixture_class :obs => 'observation'

  before(:each) do
    session[:user_id] = users(:admin).id
  end

  before(:each) do
    @patient = Patient.find(patient(:mary).patient_id)
  end

  it "should use PatientsController" do
    controller.should be_an_instance_of(PatientsController)
  end

  describe "GET 'show'" do
    it "should show patient details" do
      get :show, {:patient_id => @patient.patient_id}
      response.should render_template("show")
    end
  end

  describe "GET 'tab_lab_results'" do
    it "should display patient's lab results" do
      get :tab_lab_results
      response.should render_template("tab_lab_results")
    end

    it "should get the patient's syphilis result" do
      @syphilis_result = Observation.find_by_concept_id(concept_name(:syphilis_result).concept_id)
      @syphilis_result.value_text.should_not be_nil
    end

    it "should get the patient's syphilis result test date" do
      @syphilis_result_date = Observation.find_by_concept_id(concept_name(:syphilis_result_test_date).concept_id)
      @syphilis_result_date.value_datetime.should_not be_nil
    end

    it "should get the patient's HB 1 result" do
      @hb_1_result = Observation.find_by_concept_id(concept_name(:hb_1_result).concept_id)
      @hb_1_result.value_numeric.should_not be_nil
    end

    it "should get the patient's HB 1 result test date" do
      @hb_1_result_date = Observation.find_by_concept_id(concept_name(:hb_1_result_test_date).concept_id)
      @hb_1_result_date.value_datetime.should_not be_nil
    end

    it "should get the patient's HB 2 result" do
      @hb_2_result = Observation.find_by_concept_id(concept_name(:hb_2_result).concept_id)
      @hb_2_result.value_numeric.should_not be_nil
    end

    it "should get the patient's HB 2 result test date" do
      @hb_2_result_date = Observation.find_by_concept_id(concept_name(:hb_2_result_test_date).concept_id)
      @hb_2_result_date.value_datetime.should_not be_nil
    end

    it "should get the patient's CD4 Count result" do
      @cd4_count = Observation.find_by_concept_id(concept_name(:cd4_count).concept_id)
      @cd4_count.value_numeric.should_not be_nil
    end

    it "should get the patient's CD4 Count test date" do
      @cd4_count_test_date = Observation.find_by_concept_id(concept_name(:cd4_count_test_date).concept_id)
      @cd4_count_test_date.value_datetime.should_not be_nil
    end
  end

  describe "GET 'tab_examinations_management'" do
    it "should display patient's examinations management results" do
      get :tab_examinations_management, {:patient_id => Patient.find(patient(:mary).patient_id)}
      response.should render_template("tab_examinations_management")
    end

    it "should get the patient's height" do
      @height = Observation.find_by_concept_id(concept_name(:height).concept_id)
      @height.value_numeric.should_not be_nil
    end

    it "should get the patient's response to 'ever had multiple pregnancy?'" do
      @multiple_pregnancy = Observation.find_by_concept_id(concept_name(:multiple_pregnancy).concept_id)
      @multiple_pregnancy.value_coded.should_not be_nil
    end

    it "should get the patient's WHO Clinical Stage'" do
      @who_stage = Observation.find_by_concept_id(concept_name(:who_clinical_stage).concept_id)
      @who_stage.should_not be_nil
    end
  end

  describe "GET 'tab_medical_history'" do
    it "should display patient's medical history summary" do
      get :tab_medical_history
      response.should render_template("tab_medical_history")
    end

    it "should get the patient's response to 'ever had asthma?" do
      @asthma = Observation.find_by_concept_id(concept_name(:ever_had_asthma).concept_id)
      @asthma.value_coded.should_not be_nil
    end

    it "should get the patient's response to 'ever had hypertension?" do
      @hypertension = Observation.find_by_concept_id(concept_name(:ever_had_hypertension).concept_id)
      @hypertension.value_coded.should_not be_nil
    end

    it "should get the patient's response to 'ever had diabetes?" do
      @diabetes = Observation.find_by_concept_id(concept_name(:ever_had_diabetes).concept_id)
      @diabetes.value_coded.should_not be_nil
    end

    it "should get the patient's response to 'ever had epilepsy?" do
      @epilepsy = Observation.find_by_concept_id(concept_name(:ever_had_epilepsy).concept_id)
      @epilepsy.value_coded.should_not be_nil
    end

    it "should get the patient's response to 'ever had renal disease?" do
      @renal_disease = Observation.find_by_concept_id(concept_name(:ever_had_renal_disease).concept_id)
      @renal_disease.value_coded.should_not be_nil
    end

    it "should get the patient's response to 'ever had a fistula repair?" do
      @fistula_repair = Observation.find_by_concept_id(concept_name(:ever_had_a_fistula_repair).concept_id)
      @fistula_repair.value_coded.should_not be_nil
    end

    it "should get the patient's response to 'do you have a spine or leg deform?" do
      @spine_or_deform = Observation.find_by_concept_id(concept_name(:do_you_have_a_spine_or_leg_deform).concept_id)
      @spine_or_deform.value_coded.should_not be_nil
    end
  end

  describe "GET 'tab_obstetric_history'" do
    it "should display patient's obstetric history summary" do
      get :tab_obstetric_history
      response.should render_template("tab_obstetric_history")
    end

    it "should get the patient's number of deliveries" do
      @deliveries = Observation.find_by_concept_id(concept_name(:number_of_deliveries).concept_id)
      @deliveries.value_numeric.to_i.should be_eql(2)
    end

    it "should get the patient's number of abortions" do
      @abortions = Observation.find_by_concept_id(concept_name(:number_of_abortions).concept_id)
      @abortions.value_numeric.to_i.should be_eql(2)
    end

    it "should get the patient's response to 'ever had still births?'" do
      @deliveries = Observation.find_by_concept_id(concept_name(:ever_had_still_births).concept_id)
      @deliveries.value_coded.to_i.should be_eql(1066)
    end

    it "should get the patient's response to 'ever had c-section?'" do
      @still_births = Observation.find_by_concept_id(concept_name(:ever_had_c_sections).concept_id)
      @still_births.value_coded.to_i.should be_eql(1066)
    end

    it "should get the patient's response to 'ever had a vacuum extraction?'" do
      @vacuum = Observation.find_by_concept_id(concept_name(:ever_had_a_vacuum_extraction).concept_id)
      @vacuum.value_coded.to_i.should be_eql(1066)
    end

    it "should get the patient's response to 'ever had symphysiotomy?'" do
      @symphysiotomy = Observation.find_by_concept_id(concept_name(:ever_had_symphysiotomy).concept_id)
      @symphysiotomy.value_coded.to_i.should be_eql(1066)
    end

    it "should get the patient's hemorrhage?'" do
      @vacuum = Observation.find_by_concept_id(concept_name(:hemorrhage).concept_id)
      @vacuum.value_coded.to_i.should be_eql(7792)
    end

    it "should get the patient's pre-eclampsia" do
      @symphysiotomy = Observation.find_by_concept_id(concept_name(:pre_eclampsia).concept_id)
      @symphysiotomy.value_coded.to_i.should be_eql(1066)
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
      get :observations, {:patient_id => Patient.find(patient(:mary).patient_id)}
      response.should render_template("observations")
    end
  end

  describe "GET 'preventative_medications'" do
    it "should display patient's preventative medications summary" do
      get :preventative_medications, {:patient_id => Patient.find(patient(:mary).patient_id)}
      response.should render_template("preventative_medications")
    end
  end

  describe "GET 'hiv_status'" do
    it "should display patient's hiv status summary" do
      get :hiv_status, {:patient_id => Patient.find(patient(:mary).patient_id)}
      response.should render_template("hiv_status")
    end
  end

  describe "GET 'pmtct_management'" do
    it "should display patient's pmtct management action successfully" do
      get :pmtct_management, {:patient_id => Patient.find(patient(:mary).patient_id)}
      response.should render_template("pmtct_management")
    end
  end

  describe "GET 'obstetric_history'" do
    it "should get the obstetric_history action successfully" do
      get :obstetric_history, {:patient_id => Patient.find(patient(:mary).patient_id)}
      response.should render_template("obstetric_history")
    end
  end

  describe "GET 'medical_history'" do
    it "should get the medical_history action successfully" do
      get :medical_history, {:patient_id => Patient.find(patient(:mary).patient_id)}
      response.should render_template("medical_history")
    end
  end

  describe "GET 'examinations_management'" do
    it "should get the examinations_management action successfully" do
      get :examination_management, {:patient_id => Patient.find(patient(:mary).patient_id)}
      response.should render_template("examination_management")
    end
  end

  describe "GET 'lab_results'" do
    it "should get the lab_results action successfully" do
      get :lab_results, {:patient_id => Patient.find(patient(:mary).patient_id)}
      response.should render_template("lab_results")
    end
  end

  describe "GET 'void'" do
    it "should void encounters" do
      get :void, {:encounter_id => encounter(:mary_hiv_status).encounter_id}

      @encounter = encounter(:mary_hiv_status)
      @patient = Patient.find(encounter(:mary_hiv_status).patient_id)
      @encounter.void
      response.should redirect_to("/patients/tab_visit_summary/?patient_id=#{@patient.patient_id}")
    end
  end

end
