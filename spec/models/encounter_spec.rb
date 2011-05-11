require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Encounter do
  fixtures :encounter

  it "should exist" do
    Encounter.exists?.should be_true
  end

  it "should find encounter by encounter_type" do
    @encounter = Encounter.find(encounter(:mary_observations).encounter_id)
    @encounter.should_not be_blank
  end
end
