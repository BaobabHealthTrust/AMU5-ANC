require File.dirname(__FILE__) + '/../test_helper'

class UserControllerTest < ActionController::TestCase
  fixtures :users, :role, :user_role, :person_name

  def setup
    @controller = UserController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  context "User controller" do

    should "create a user with valid attributes" do
      logged_in_as :mikmck, :registration do
        post :create, {"person_name"=>{"family_name"=>"banda","given_name"=>"john"},
                   "user"=>{"username"=>"jbanda", "user_id"=>50, "password"=>"banda"},
                   "user_role"=>{"role_id"=>"Informatics Manager"},
                   "user_confirm"=>{"password"=>"banda"}}

        assert_equal 'User was successfully created.', flash[:notice]
        assert_response :redirect
      end
    end

    should "not create user if password mismatch" do
      logged_in_as :mikmck, :registration do
        post :create, {"person_name"=>{"family_name"=>"banda","given_name"=>"john"},
                   "user"=>{"username"=>"jbanda", "user_id"=>50, "password"=>"banda"},
                   "user_role"=>{"role_id"=>"Informatics Manager"},
                   "user_confirm"=>{"password"=>"test"}}

        assert_equal 'Password Mismatch', flash[:notice]
        assert_response :redirect
      end
    end

    should "not create user user already exists" do
      logged_in_as :mikmck, :registration do
        post :create, {"person_name"=>{"family_name"=>"Waters","given_name"=>"Evan"},
                   "user"=>{"username"=>"mikmck", "user_id"=>1, "password"=>"test"},
                   "user_role"=>{"role_id"=>"Superuser"},
                   "user_confirm"=>{"password"=>"test"}}

        assert_equal 'Username already in use', flash[:notice]
        assert_response :redirect
      end
    end

    should "edit user" do
      logged_in_as :mikmck, :registration do
        post :edit , {"id" => users(:mikmck).user_id}
        assert_response :success
      end
    end

    should "edit user names" do
      logged_in_as :mikmck, :registration do
        post :username, {"person_name"=>{"family_name"=>"banda","given_name"=>"john"},
                   "user"=>{"username"=>"jbanda", "user_id"=>50}}
        assert_response :success
      end
    end

    should "change user password" do
      logged_in_as :mikmck, :registration do
        post :change_password, {"id"=>"1", "user_confirm"=>{"password"=>"testing"},
                                "user"=>{"password"=>"testing"}}

        assert_redirected_to(:action => "show", :id => 1)
      end
    end

    should "select user" do
      logged_in_as :mikmck, :registration do
        post :search_user, {"id"=>users(:mikmck).id, "user"=>{"username"=>"mikmck"}}

        @user = User.find_by_username(users(:mikmck).username)
        assert_redirected_to(:action => "show", :id => @user.id)
      end
    end

   should "redirect to user_menu" do
      logged_in_as :mikmck, :registration do
        post :user_menu
        assert_response :success
      end
    end

   should "update user details" do
     logged_in_as :mikmck, :registration do
       post :update, {"person_name"=>{"family_name"=>"banda", "given_name"=>"mary"},
                     "id"=>"2", "user"=>{"username"=>"mbanda"}}

       assert_equal 'User was successfully updated.', flash[:notice]
       assert_redirected_to(:action => "show", :id => 2)
     end
   end

   should "display user details" do
     logged_in_as :mikmck, :registration do
       post :show
       assert_response :success
     end
   end

   should "login a valid user" do
     logged_in_as :mikmck, :registration do
       post :login
       session[:user_id]=nil
       assert_response :success
     end
   end

   should "logout a user" do
     logged_in_as :mikmck, :registration do
       post :logout
       assert_redirected_to("user/login")
     end
   end

   should "add user role" do
     logged_in_as :mikmck, :registration do
       post :add_role, {:id => users(:registration).user_id,
                        :user_role => {"role_id"=>"Clinician"}}

       assert_equal "You have successfuly added the role of Clinician", flash[:notice]
       assert_redirected_to("user/show")
     end
   end

   should "delete user role" do
     logged_in_as :mikmck, :registration do
#TODO
=begin
       post :delete_role, {:id => users(:registration).user_id,
                           :user_role => {"role_id"=>"Clinician"}}

       role = Role.find_by_role(role(:clinician).role)
       user_role =  UserRole.find_by_role_and_user_id(role, users(:registration).user_id)
       #raise"#{user_role.inspect}"
       assert_equal "You have successfuly removed the role of Clinician", flash[:notice]
       assert_redirected_to("user/show")
=end
     end
   end

  end
end
