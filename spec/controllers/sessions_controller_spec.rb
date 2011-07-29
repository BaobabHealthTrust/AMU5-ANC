require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe SessionsController do
  integrate_views
  fixtures :users, :role, :user_role, :person_name

  before(:each) do
    session[:user_id] = users(:admin).id
  end
  
  before(:each) do
    @login_user = {:login => "admin", :password => "test"}
  end

  #Delete this example and add some real ones
  it "should use SessionsController" do
    controller.should be_an_instance_of(SessionsController)
  end

  describe "GET 'create'" do
    it "should get the login action successfully" do
      get :create
      response.should be_success
    end

    #TODO - there must be a better way of testing this.
    it "should login a valid user" do
      user = User.authenticate(@login_user[:login], @login_user[:password])
      user = User.find_by_username(@login_user[:login])
      user.should_not be_nil

      #response.should redirect_to("")
    end
  end

  describe "GET 'destroy'" do
    it "should logout a valid user" do
      get :destroy
      session[:user_id] = nil
      flash[:notice].should be_eql("You have been logged out.")
      response.should redirect_to("/")
    end
  end

end
