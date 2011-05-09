require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe PersonName do
  fixtures :person_name
  
  before(:each) do
    @valid_attributes = {:person_name_id => 4, :preferred => 0, :person_id => 4,
                      :prefix => 0, :given_name => "chikondi", :middle_name => "",
                      :family_name_prefix => "", :family_name => "banda",
                      :family_name2 => "", :family_name_suffix => "", :degree => "",
                      :creator => 1, :date_created => "2011-04-18 00:00:00", :changed_by => 1,
                      :date_changed => "2011-04-18 00:00:00", :uuid => "1ff85fd2-268f-102d-a2b3-16da04859148"}
  end

  it "should create a new instance given valid attributes" do
    PersonName.create!(@valid_attributes)
  end
  
  it "should exist" do
    PersonName.exists?.should be_true
  end
 
  it "should be valid after saving" do
    @valid_attributes = PersonName.new
    @valid_attributes.save
    @valid_attributes.should be_valid
  end
end
