require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe PersonAddress do
  fixtures :person_address

  it "should exist" do
    PersonAddress.exists?.should be_true
  end
end
