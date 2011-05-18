require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe ReportsController do

  integrate_views
  fixtures :users, :encounter, :encounter_type, :obs, :concept_name, :patient

  before(:each) do
    session[:user_id] = users(:admin).id
  end

  it "should use ReportsController" do
    controller.should be_an_instance_of(ReportsController)
  end

  describe "GET 'index'" do
    it "should get the index action" do
      get :index
      response.should be_success
    end
  end

  describe "GET 'report'" do
    it "should get the report action" do
      get :report
      response.should render_template("reports/report")
    end
  end

  describe "GET 'select'" do
    it "should get the select action" do
      get :select
      response.should render_template("reports/select")
    end
  end
end
