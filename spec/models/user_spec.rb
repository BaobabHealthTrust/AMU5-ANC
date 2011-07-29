require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'digest/sha1'

describe User do
  fixtures :users, :role, :user_role, :person_name

  before(:each) do
    @params_user = {:family_name => "banda",:given_name => "james",
                   :username => "admin", :user_id => 4, :password => "test",
                   :role_id => "Informatics Manager", :user_confirm => "test"}

    @user = User.new(@params_user[:user])
    @user.save
  end

  it "should exist" do
   @user = User.find_by_username(@params_user[:username])
   @user.should be_valid
  end

  it "should not have a blank username" do
    @params_user[:username].should_not be_blank
  end

  it "should have username with more than 4 characters" do
    @params_user[:username].length.should >= 4
  end

  it "should not have a blank password" do
    @params_user[:password].should_not be_blank
  end

  it "should have password with more than 4 characters" do
    @params_user[:password].length.should >= 4
  end

  it "should have password matching user_confirm password" do
    @params_user[:password].should be_eql(@params_user[:user_confirm])
  end

  it "should encrypt password" do
    @salt = User.random_string(10)

    encrypted_password = Digest::SHA1.hexdigest(@params_user[:password]+@salt)
    encrypted_password.length.should >= 40
  end

  it "should not have a blank role" do
    @params_user[:role_id].should_not be_blank
  end

  it "should have a valid role" do
    @role = Role.find_by_role(@params_user[:role_id])
    @role.should be_valid
  end

  it "should be valid after saving" do
    users(:admin).should be_valid
  end

  it "should be authenticated on login" do
    user = User.find_by_username(@params_user[:username])

    user && user.authenticated?(@params_user[:password]) ? u : nil
    user.should be_true
  end

  it "should create a salt of length not less than 40" do
    @salt = User.random_string(10)
    @salt.length.should >= 10
  end

end
