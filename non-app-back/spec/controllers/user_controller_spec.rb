require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe UserController do
  integrate_views
  fixtures :users, :role, :user_role, :person_name
  
  before(:each) do
    session[:user_id] = users(:admin).id
  end

  before(:each) do
   post :new, :user => {"person_name"=>{"voided"=>0,"family_name"=>"banda","given_name"=>"john"},
                   "user"=>{"username"=>"jbanda", "user_id"=>50, "password"=>"banda"},
                   "user_role"=>{"role_id"=>"Clinician"},
                   "user_confirm"=>{"password"=>"banda"}}
  end

  it "should use UserController" do
    controller.should be_an_instance_of(UserController)
  end

  describe "GET 'create'" do
     it "should not create an already existing user" do
      get :create, {"person_name"=>{"voided"=>0,"family_name"=>"admin","given_name"=>"test"},
                         "user"=>{"username"=>"admin", "user_id"=>50, "password"=>"banda"},
                         "user_role"=>{"role_id"=>"Clinician"},
                         "user_confirm"=>{"password"=>"banda"}}
      flash[:notice].should be_eql("Username already in use")
      response.should redirect_to("user/new")
    end

    #supposed to flash notice if password mismatched
    it "should not create user if password mismatch" do
      get :create, {"person_name"=>{"voided"=>0,"family_name"=>"admin","given_name"=>"test"},
                         "user"=>{"username"=>"admin", "user_id"=>50, "password"=>"banda"},
                         "user_role"=>{"role_id"=>"Clinician"},
                         "user_confirm"=>{"password"=>"jbanda"}}
      #flash[:notice].should be_eql("Password Mismatch")
      response.should redirect_to"user/new"
    end

    it "should create a user with valid attributes" do
     get :create, {"person_name"=>{"family_name"=>"banda","given_name"=>"john"},
                    "user"=>{"username"=>"joebanda", "user_id"=>50, "password"=>"banda"},
                    "user_role"=>{"role_id"=>"Clinician"},
                    "user_confirm"=>{"password"=>"banda"}}
                         
     @user = User.new(params[:user])
     @user.save
     flash[:notice].should be_eql("User was successfully created.")
     response.should redirect_to("user/show")
    end
  end

  describe "GET 'login'" do
    it "should get the login action" do
      get :login
      response.should be_success
    end

    # TODO
    # to rewrite this
    it "should login a valid user" do
      post :login, {:login => "admin", :password => "testing"}
      user = User.authenticate(params[:login], params[:password])
      user.should be_nil
      response.should be_success
      #flash[:notice].should be_eql("Invalid username or password")
    end
  end

  describe "GET 'new'" do
    it "should get the new action successfully" do
      get :new
      response.should be_success
    end

    it "should create new user" do
      post :new, :user=>{"user_role"=>{"role_id"=>"Adults"},
                         "person_name"=>{"voided"=>0,"family_name"=>"banda",
                                         "given_name"=>"john"},
                         "user_confirm"=>{"password"=>"banda"},
                         "user"=>{"username"=>"jbanda", "user_id"=>50, "password"=>"banda"}}
      response.should be_success
    end
  end

  describe "GET 'update'" do
    it "should save the changes made to user" do
     get :update, {"person_name"=>{"family_name"=>"banda", "given_name"=>"mary"},
                     "id"=>"2", "user"=>{"username"=>"mbanda"}}

     person_name = PersonName.new
     person_name.family_name = params[:person_name]["family_name"]
     person_name.given_name = params[:person_name]["given_name"]
     person_name.person_id = users(:mary_banda).user_id
     person_name.save

     PersonName.exists?.should be_true
     flash[:notice].should be_eql("User was successfully updated.")
     response.should redirect_to("user/show/2")
    end
  end

  describe "GET 'show'" do
    it "should get the show action" do
      get :show, {:user_id => users(:mary_banda).user_id}
      response.should be_success
    end
  end

  describe "GET 'edit'" do
    it "should get the edit action successfully" do
      get :edit, {:id => users(:mary_banda).user_id }
      response.should be_success
    end

    it "should save changes made to an existing user" do
      @user = User.find(users(:mary_banda).id)

      params[:user][:username] = "mbanda"
      post :edit, {:id => users(:mary_banda).user_id }

      User.find_by_username('mbanda').should_not be_nil
    end
  end

  describe "GET 'change_password'" do
    it "should get change password action successfully" do
      get :change_password, {:id => users(:mary_banda).user_id }
      response.should be_success
    end

    it "should not save password changes if password mismatch" do
      post :change_password, {"id"=>"1",
                              "user_confirm"=>{"password"=>"test"},
                              "user"=>{"password"=>"testing"}}

      flash[:notice].should be_eql("Password Mismatch")
      response.should redirect_to("user/new")
    end

    it "should save changes if password match" do
      post :change_password, {"id"=>"1",
                              "user_confirm"=>{"password"=>"test"},
                              "user"=>{"password"=>"test"}}

      flash[:notice].should be_eql("Password successfully changed")
      response.should redirect_to("user/show/1")
    end

    it "should not save changes if password characters are less than four" do
      post :change_password, {"id"=>"1",
                              "user_confirm"=>{"password"=>"tes"},
                              "user"=>{"password"=>"tes"}}

      flash[:notice].should be_eql("Password change failed")
    end
  end

  describe "GET 'select_user'" do
    it "should get the search_user action successfully" do
      get :search_user
      response.should be_success
    end

    it "should display the user details" do
      post :search_user, {"id"=>"2", "user"=>{"username"=>"mbanda"}}
      response.should redirect_to("user/show/#{users(:mary_banda).user_id}")
    end
  end

  describe "GET 'logout'" do
    it "should get the log_out action successfully" do
      get :logout
      session[:user] = nil
      response.should redirect_to("user/login")
    end
  end

  describe "GET 'signup'" do
    it "should get the signup action successfully" do
      get :signup
      response.should be_success
    end
  end

  describe "GET 'user_menu'" do
    it "should get the user_menu action successfully" do
      get :user_menu
      response.should be_success
    end
  end

  describe "GET 'username'" do
    it "should get the username action successfully" do
      get :username
      response.should be_success
    end
  end

end
