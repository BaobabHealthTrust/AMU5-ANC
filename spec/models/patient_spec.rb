require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Patient do
  fixtures :patient

  it "should exist" do
    Patient.exists?.should be_true
  end
end
