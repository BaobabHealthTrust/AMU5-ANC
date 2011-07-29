require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe PersonAddress do
  fixtures :person_address

  before(:each) do
    @person_address = {:person_address_id => 1, :person_id => 1,
                       :address2 => "Rumphi", :city_village => "Mlongoti",
                       :creator => 1, :date_created => DateTime.now,
                       :county_district => "Chiokulamayembe",
                       :uuid => "1ff746d8-268f-102d-a2b3-16da04859145"}
  end

  it "should find valid person's address" do
    @address = PersonAddress.find(person_address(:mary_address)).person_address_id
    @address.should_not be_blank
  end

  it "should not have a blank home village" do
    @person_address[:address2].should_not be_blank
  end

  it "should not have a blank current traditional authority" do
    @person_address[:county_district].should_not be_blank
  end

  it "should not have a blank current residence" do
    @person_address[:city_village].should_not be_blank
  end
end
