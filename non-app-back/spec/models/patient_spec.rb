require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Patient do
  fixtures :person, :person_name, :person_name_code,
           :person_address, :patient, :patient_identifier,
           :patient_identifier_type, :encounter

  it "should exist" do
    @patient = Patient.find_by_patient_id(patient(:mary).patient_id)
    @patient.should be_true
  end

  it "should refer to the patient identifier" do
   patient_id = patient(:mary).patient_id
   (patient_identifier(:mary_identifier).patient_id).should == patient_id
  end

  it "should get the patient_id" do
   @patient = Patient.find(patient(:mary).patient_id)
   @patient.should be_valid
  end

  it "should get the patient national_id" do
    @patient_identifier = PatientIdentifier.find(patient(:mary).patient_id)
    @patient_identifier.identifier.should be_eql("P100200000158")
  end

  it "should get the patient's age" do
    @patient_age = Person.find(patient(:mary).patient_id).birthdate
    age = (Date.today.year) - (@patient_age.year)
    age.should_not be_nil
  end

  it "should get the patient's gender" do
    @patient_gender = Person.find(patient(:mary).patient_id).gender
    @patient_gender.should_not be_nil
  end

  it "should get the patient's residence (current village)" do
    @patient_residence = PersonAddress.find(patient(:mary).patient_id).city_village
    @patient_residence.should_not be_nil
  end

  it "should get all the patient's encounters" do
   @patient = patient(:mary).encounters
   @patient.count.should be_eql(7)
  end

  it "should get the patient's encounters by date" do
   @patient = patient(:mary).encounters.find_by_date("2011-01-01 00:00:00")
   @patient.count.should be_eql(5)
  end

end
