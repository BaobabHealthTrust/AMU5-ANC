require File.dirname(__FILE__) + '/../test_helper'

class PatientsControllerTest < ActionController::TestCase
  fixtures :person, :person_name, :person_name_code, :person_address,
           :patient, :patient_identifier, :patient_identifier_type,
           :program, :concept, :concept_name, :encounter, :encounter_type

  def setup  
    @controller = PatientsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new    
  end

  context "Patient controller" do
    context "dashboard" do
      should "show the patient" do
        logged_in_as :mikmck, :registration do
          get :show, {:id => patient(:evan).id}
          assert_response :success
        end  
      end
    
      should "not show the pre art number if there is one and we are on the right location" do
        logged_in_as :mikmck, :registration do
          GlobalProperty.create(:property => 'dashboard.identifiers', :property_value => "{\"#{Location.current_location.id}\":[\"Pre ART Number\"]}")
          get :show, {:id => patient(:evan).id}
          assert_no_match /Pre ART Number/, @response.body
          assert_no_match /PART\-311/, @response.body
          assert_response :success
        end  
      end

      should "not show the pre art number if there is one and we are on the wrong location" do
        logged_in_as :mikmck, :registration do
          GlobalProperty.create(:property => 'dashboard.identifiers', :property_value => "{\"#{Location.current_location.id+1}\":[\"Pre ART Number\"]}")
          get :show, {:id => patient(:evan).id}
          assert_no_match /Pre ART Number/, @response.body
          assert_no_match /PART\-311/, @response.body
          assert_response :success
        end  
      end

      should "show the number of booked patients" do
        logged_in_as :mikmck, :registration do
          #TODO rewrite 
          get :number_of_booked_patients, {:id => patient(:evan).id, :date => Date.today}
          assert_response :success
        end
      end

      should "get opdshow" do
        logged_in_as :mikmck, :registration do
          #TODO mastercard, opdcard, opdtreatment, mastercard_printable, patient_state
          #session[:mastercard_ids] = []
          get :treatment, {:patient_id => patient(:evan).patient_id}
          assert_response :success
        end
      end

      should "get the mastercard_modify" do
        logged_in_as :mikmck, :registration do
          #TODO rewrite the test
          get :mastercard_modify, {:id => patient(:evan).patient_id, :field => 'guardian'}
          assert_redirected_to("relationships/search?patient_id=#{patient(:evan).patient_id}")
        end
      end

      should "get the general_mastercard" do
        logged_in_as :mikmck, :registration do
          #TODO rewrite the test
          get :general_mastercard, {:id => patient(:evan).patient_id, :type => 4}
          assert_response :success
        end
      end
    end
  end
end
