require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe PeopleController do
  integrate_views
  fixtures :person, :person_name, :person_name_code, 
           :person_address, :person_attribute_type, 
           :patient, :patient_identifier, :users

  before(:each) do    
    session[:user_id] = users(:admin).id
  end
  
  before(:each) do
     post :search, :person =>{"given_name"=>"mary", "family_name"=>"banda",
        "gender"=> "female"}
  end

  it "should use PeopleController" do
    controller.should be_an_instance_of(PeopleController)
  end

  describe "GET 'index'" do
    it "should get index action" do
      get :index
      response.should redirect_to("/clinic")
    end
  end
  
  describe "GET 'new'" do
    it "should get registration form" do
      get :new
      response.should be_success
    end
  end
  
  describe "GET 'search'" do
    it "should get search action" do
      get :search, {:given_name => "mary", :family_name => "banda", :gender => "F"}
      response.should be_success
    end
    
    it "should find patient by given name" do
      @person = PersonName.find_by_given_name('mary')
      @person.should be_valid
    end
=begin
    it "should find all patients with common given_names" do
    end
=end    
    it "should find patient by family name" do
      @person = PersonName.find_by_family_name('banda')
      @person.should be_valid
    end
    
    it "should find patient using a valid national_id" do
     @person_identifier = PatientIdentifier.find_by_identifier('P1701210013') 
     @person_identifier.should be_valid
    end
    
    it "should redirect to create patient using an invalid national_id" do
     @person_identifier = PatientIdentifier.find_by_identifier('P1701211562') 
     @person_identifier.should be_nil
     response.should render_template("search")  
    end
  end
  
  describe "GET 'demographics'" do
   it "should get edit demographics" do
    get :demographics
    response.should be_success
   end 
  end

  describe "GET 'create'" do
    it "should create patient" do
      get :create, :person => {:birth_year => 1982,:birth_month => 8,:birth_day => 22,
                             :gender => 'F',:cell_phone_number => 'Unknown',
                             :names => {:given_name => 'Mary', 
                                        :family_name2 => 'Nazimbiri',
                                        :family_name => 'Mbewe'},
                             :addresses => {:county_district => 'Gomani', 
                                            :city_village => 'Area 25A',
                                            :address1 => 'Ntcheu'},
                             :occupation => 'House Wife'}   
      response.should be_redirect
   end
   
   it "should save a valid patient" do
    #should save person attributes
    #should save person_names attributes
    #should save person addresses attributes
    #should save patient details
   end
  end
  
  describe "GET 'select'" do
    it "should get select action" do
      get :select
      response.should redirect_to("/people/new")
    end
  end
end
