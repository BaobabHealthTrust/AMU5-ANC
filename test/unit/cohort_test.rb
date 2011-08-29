#$:.unshift File.join(File.dirname(__FILE__),'..','lib')

require File.dirname(__FILE__) + '/../test_helper'
#require 'test/unit'
#require 'cohort'

#class Cohort < Test::Unit::TestCase
class CohortTest < ActiveSupport::TestCase

  fixtures :program, :concept, :concept_name, :concept_answer, :concept_numeric

  context "Cohort Report" do

    should "set start and end times for the report" do
      cohort = Cohort.new('1900-01-01', '2011-03-31')
      assert_equal '1900-01-01', cohort.start_date
      assert_equal '2011-03-31 23:59:59', cohort.end_date
    end

  end

end
