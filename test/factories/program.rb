Factory.define :program, :class => :program do |program|
  program.name "HIV PROGRAM"
  program.program_id 100
  program.concept Factory(:concept)
  program.creator { Factory.creator }
end
