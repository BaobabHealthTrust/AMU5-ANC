require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe EncountersController do
  integrate_views
  fixtures :person, :person_name, :person_name_code, :person_address,
           :patient, :patient_identifier, :patient_identifier_type,
           :concept, :concept_name, :concept_class,
           :encounter, :obs, :users

  before(:each) do
    session[:user_id] = users(:admin).id
  end

  #Delete this example and add some real ones
  it "should use EncountersController" do
    controller.should be_an_instance_of(EncountersController)
  end

  #get patient id and redirect to patient/show
  describe "GET 'new'" do
    it "should get the new action" do
      get :new, {"patient_id" => 1, "creator" => 1,
                                "date_created" => "2011-04-18 00:00:00",
                                "changed_by" => 1, "date_changed" => "2011-04-18 00:00:00"}
      response.should redirect_to("patients/show/1")
    end
  end

  #to create an encounter and redirect to patients/show
  describe "GET 'create'" do
    it "should create an encounter successfully" do
      get :create, {"encounter" => {"provider_id"=>"1","encounter_type_name"=>"OBSERVATIONS",
                    "patient_id" => "1", "encounter_datetime"=>"2011-05-04T14:03:53+02:00"},
                    "observations" => [{"value_coded"=>"", "value_datetime" => "", "order_id" => "",
                    "obs_group_id" => "", "value_drug"=>"", "patient_id" => "1",
                    "value_coded_or_text_multiple" => [""], "value_boolean" => "",
                    "concept_name" => "GRAVIDA", "value_text" => "",
                    "obs_datetime" => "2011-05-04T14:03:53+02:00", "value_numeric" => "3"}]}

      response.should redirect_to("/patients/show/1")
    end
  end

  describe "GET 'void'" do
    it "should void encounter successfully" do
      get :void, {:id => encounter(:mary_hiv_status).encounter_id}
      response.should be_success
    end
  end
end
