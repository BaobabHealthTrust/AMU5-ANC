Factory.define :concept, :class => :concept do |concept|
  concept.concept_datatype {|concepts| concepts.concept_datatype}
  concept.concept_class    {|concepts| concepts.concept_class}
  concept.creator          { Factory.creator }
  concept.is_set           { 0 }
  concept.retired          { 0 }
end
