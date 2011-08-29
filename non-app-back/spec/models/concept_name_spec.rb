require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe ConceptName do
  fixtures :concept_name

  before(:each) do
    @concept_name = {"name" => "GRAVIDA", "concept_id" => 1755,
                         "date_created" => DateTime.now, "creator" => 1,
                         "locale" => "en"}
  end

  it "should create a new instance given valid attributes" do
    ConceptName.create!(@concept_name)
  end

  it "should find a saved concept_name" do
    @concept_name = ConceptName.find_by_concept_id(1755)
    @concept_name.should_not be_nil
  end
end
