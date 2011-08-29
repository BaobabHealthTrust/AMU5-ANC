require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe PersonName do
  fixtures :person_name, :person

  before(:each) do
   @person_name = {:person_name_id => 4, :person_id => 4,
                   :given_name => "chikondi", :family_name => "banda",
                   :family_name2 => "nazimbiri"}
  end

  it "should create a new instance given valid attributes" do
    PersonName.create!(@person_name)
  end

  it "should not have a blank surname" do
    @person_name[:family_name].should_not be_blank
  end

  it "should not have a blank first name" do
    @person_name[:given_name].should_not be_blank
  end

  it "should not have a blank mother's surname" do
    @person_name[:family_name2].should_not be_blank
  end

  it "should be valid after saving" do
    @valid_attributes = PersonName.new(@person_name)
    @valid_attributes.save
    @valid_attributes.should be_valid
  end
end
