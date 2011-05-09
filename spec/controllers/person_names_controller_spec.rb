require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe PersonNamesController do
  fixtures :person_name, :person, :users
 
  it "should use PersonNamesController" do
    controller.should be_an_instance_of(PersonNamesController)
  end
  
  before(:each) do    
    session[:user_id] = users(:admin).id
  end
end
