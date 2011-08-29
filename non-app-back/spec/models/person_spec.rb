require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Person do
  fixtures :person

  it "should find person details" do
   @person = Person.find(person(:mary))
   @person.should_not be_blank
  end

  it "should not have age below 13" do
    @age = ((Date.today.year) - (person(:mary).birthdate.year))
    @age.should_not <= 13
  end

  it "should not have a blank year of birth" do
   @year_of_birth = person(:mary).birthdate.year
   @year_of_birth.should_not be_blank
  end

  it "should not have year of birth less than 1940" do
   @year_of_birth = person(:mary).birthdate.year
   @year_of_birth.should_not <= 1940
  end

  it "should not have year of birth greater than today" do
   @year_of_birth = person(:mary).birthdate.year
   @year_of_birth.should_not >= Date.today.year
  end

  it "should not have gender as male" do
    person(:mary).gender.should == "F"
  end

end
