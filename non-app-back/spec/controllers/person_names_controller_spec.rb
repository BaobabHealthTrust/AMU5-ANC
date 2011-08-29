require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe PersonNamesController do
  fixtures :person_name, :person, :users

  it "should use PersonNamesController" do
    controller.should be_an_instance_of(PersonNamesController)
  end

  before(:each) do
    session[:user_id] = users(:admin).id
  end

  describe "GET 'family_names'" do
    it "should get the family names action" do
      get :family_names
      response.should be_success
    end
  end

  describe "GET 'given_names'" do
    it "should get the family action" do
      get :given_names
      response.should be_success
    end
  end

  describe "GET 'family_names2'" do
    it "should get the mother's name action" do
      get :family_name2
      response.should be_success
    end
  end
=begin
#TODO
#think of a better way of doing this
  describe "GET 'search'" do
    it "should get the search action" do
      get :search, {"field_name" => "given_name", "search_string" => "mary"}
      response.should be_success
    end
  end
=end
end
