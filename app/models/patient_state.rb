class PatientState < ActiveRecord::Base
  set_table_name "patient_state"
  set_primary_key "patient_state_id"
  include Openmrs
  belongs_to :patient_program, :conditions => {:voided => 0}
  belongs_to :program_workflow_state, :foreign_key => :state, :class_name => 'ProgramWorkflowState'
#, :conditions => {:retired => 0}

  named_scope :current, :conditions => ['start_date IS NOT NULL AND DATE(start_date) <= CURRENT_DATE() AND (end_date IS NULL OR DATE(end_date) > CURRENT_DATE())']

  def after_save
    # If this is the only state and it is not initial, oh well
    # If this is a terminal state then close the program    
    patient_program.complete(end_date) if program_workflow_state.terminal != 0 rescue nil
  end
  
  def to_s
	workflow_state = ProgramWorkflowState.find_state state
	s = workflow_state.concept.fullname
    if start_date
      s = s + " #{start_date.strftime('%d/%b/%Y')}"
    end

    if end_date
      s = s + "-#{end_date.strftime('%d/%b/%Y')}"
    end
    s
  end
end
