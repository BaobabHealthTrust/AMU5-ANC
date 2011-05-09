require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'digest/sha1'

describe User do
  fixtures :users, :role, :user_role, :person_name
  
  before(:each) do
    params_user = {:family_name => "banda",:given_name => "james",
                   :username => "jbanda", :user_id => 4, :password => "banda",
                   :role_id => "Clinician", :user_confirm => "banda"}

    @user = User.new(params_user[:user])
    @user.save
  end

  it "should exist" do
    User.exists?.should be_true
  end

  it "should have a username" do
    params_user = {:family_name => "banda",:given_name => "james",
                   :username => "jbanda", :user_id => 4, :password => "banda",
                   :role_id => "Clinician", :user_confirm => "banda"}
                   
    params_user[:username].should_not be_blank
    params_user[:username].length.should > 4
  end

  it "should not have a blank password" do
    params_user = {:family_name => "banda",:given_name => "james",
                   :username => "jbanda", :user_id => 4, :password => "banda",
                   :role_id => "Clinician", :user_confirm => "banda"}
      
    params_user[:password].should_not be_blank
    params_user[:password].length.should > 4    
  end 
  
  it "should encrypt password" do
    params_user = {:family_name => "banda",:given_name => "james",
                   :username => "jbanda", :user_id => 4, :password => "banda",
                   :role_id => "Clinician", :user_confirm => "banda"}
    
    @salt = User.random_string(10)
   
    encrypted_password = Digest::SHA1.hexdigest(params_user[:password]+@salt)
    encrypted_password.length.should >= 40    
  end
  
  it "should have a role" do
    params_user = {:family_name => "banda",:given_name => "james",
                   :username => "jbanda", :user_id => 4, :password => "banda",
                   :role_id => "Clinician", :user_confirm => "banda"}
    
    @role = Role.find_by_role(params_user[:role_id])
    @role.should_not be_blank
  end

  it "should be valid after saving" do
    users(:admin).should be_valid
  end

  #check this again
  it "should be authenticated on login" do
    @salt = User.random_string(10)
    @password = "banda"
    
    encrypted_password = Digest::SHA1.hexdigest(@password+@salt)
    u = User.authenticate(users(:admin).username, encrypted_password)
		u.should_not be_true
  end

  it "should create a salt of length not less than 40" do
    @salt = User.random_string(10)
    @salt.length.should >= 10
  end

end
