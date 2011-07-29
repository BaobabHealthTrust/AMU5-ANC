require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe PatientIdentifier do
  fixtures :patient, :patient_identifier

  it "should exist" do
    PersonName.exists?.should be_true
  end
end
