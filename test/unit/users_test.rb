require File.dirname(__FILE__) + '/../test_helper'
require 'digest/sha1'
require 'digest/sha2'

class UsersTest < ActiveSupport::TestCase
  context "User" do
    fixtures :users, :role, :user_role, :person_name

    should "be valid" do
     assert User.make.valid?
    end

    should "contain a username" do
      user = users(:mikmck)
      assert_not_nil(user.username)
      assert user.username.length >= 4
    end

   should "contain a password" do
    user =  {:family_name => "banda",:given_name => "james",
             :username => "admin", :user_id => 4, :password => "test",
             :role_id => "Informatics Manager", :user_confirm => "test"}

     assert_not_nil(user[:password])
     assert_equal(user[:password], user[:user_confirm])
   end

   should "encrypt a password" do
    user =  {:password => "test"}

    @salt = User.random_string(10)

    encrypted_password = User.encrypt(user[:password],@salt)
    assert_equal encrypted_password.length, 40
   end

   should "authenticated on login" do
    login ="mikmck"
    password = "mike"
    user = User.authenticate(login, password)
    assert user.valid?
   end

   should "create a salt of length not less than 10" do
    @salt = User.random_string(10)
    assert_equal @salt.length, 10
   end

  end
end
