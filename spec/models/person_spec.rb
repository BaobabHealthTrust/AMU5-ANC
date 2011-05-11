require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Person do
  fixtures :person

  before(:each) do
     @invalid_person = {:person_id => "2", :gender => "M", :birthdate => "",
                        :birthdate_estimated => 13, :dead => "#{0}", :death_date => "",
                        :cause_of_death => "#{0}", :creator => "#{1}",
                        :date_created => "2011-04-18 00:00:00",
                        :changed_by => "#{1}", :date_changed => "2011-04-18 00:00:00",
                        :voided => "#{0}", :uuid => "1ff5df82-268f-102d-a2b3-16da04859146"}
  end

  it "should exist" do
    Person.exists?.should be_true
  end

  it "should not have age below 13" do
    @age = ((Date.today.year) - (person(:mary).birthdate.year))
    @age.should_not <= 13
  end

  it "should not have gender as male" do
    person(:mary).gender.should == "F"
  end

end
