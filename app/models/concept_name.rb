class ConceptName < ActiveRecord::Base
  set_table_name :concept_name
  set_primary_key :concept_name_id
  include Openmrs
  has_many :concept_name_tag_maps # no default scope
  has_many :tags, :through => :concept_name_tag_maps, :class_name => 'ConceptNameTag'
  belongs_to :concept, :conditions => {:retired => 0}
  named_scope :tagged, lambda{|tags| tags.blank? ? {} : {:include => :tags, :conditions => ['concept_name_tag.tag IN (?)', Array(tags)]}}
  named_scope :typed, lambda{|tags| tags.blank? ? {} : {:conditions => ['concept_name_type IN (?)', Array(tags)]}}

	#TODO Need 
  # This method gets the collection of all short forms of frequencies as used into make this method a lot more generic
  # the Diabetes Module and returns only no-empty values or an empty array if none
  # exist
  def self.drug_frequency
    self.find_by_sql("SELECT name FROM concept_name WHERE concept_id IN \
                        (SELECT answer_concept FROM concept_answer c WHERE \
                        concept_id = (SELECT concept_id FROM concept_name \
                        WHERE name = 'DRUG FREQUENCY CODED')) AND concept_name_id \
                        IN (SELECT concept_name_id FROM concept_name_tag_map \
                        WHERE concept_name_tag_id = (SELECT concept_name_tag_id \
                        FROM concept_name_tag WHERE tag = 'preferred_dmht'))").collect {|freq|
                            freq.name rescue nil
                        }.compact rescue []
  end

end

