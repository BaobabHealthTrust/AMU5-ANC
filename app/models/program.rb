class Program < ActiveRecord::Base
  set_table_name "program"
  set_primary_key "program_id"
  include Openmrs
  belongs_to :concept, :conditions => {:retired => 0}
  has_many :patient_programs, :conditions => {:voided => 0}
  has_many :program_workflows, :conditions => {:retired => 0}
  has_many :program_workflow_states, :through => :program_workflows

  # Actually returns +Concept+s of suitable +Regimen+s for the given +weight+
  # and this +Program+
  def regimens(weight=nil)
    Regimen.program(program_id).criteria(weight).all(
      :select => 'concept_id', 
      :group => 'concept_id, program_id',
      :include => :concept, :order => 'regimen_id').map(&:concept)
  end
end
