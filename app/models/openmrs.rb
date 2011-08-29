module Openmrs
  module ClassMethods
    def assign_scopes
      col_names = self.columns.map(&:name)
      self.default_scope :conditions => "#{self.table_name}.voided = 0" if col_names.include?("voided")
      self.default_scope :conditions => "#{self.table_name}.retired = 0" if col_names.include?("retired")
    end
    
    # We needed a way to break out of the default scope, so we introduce inactive
    def inactive(*args)
      col_names = self.columns.map(&:name)
      scope = {}
      scope = {:conditions => "#{self.table_name}.voided = 1"} if col_names.include?("voided")
      scope = {:conditions => "#{self.table_name}.retired = 1"} if col_names.include?("retired")      
      with_scope({:find => scope}, :overwrite) do
        if ([:all, :first].include?(args.first))
          self.find(*args)
        else
          self.all(*args)      
        end  
      end
    end

    # Shortcut for  looking up OpenMRS models by name using symbols or name
    # e.g. Concept[:diagonis] instead of Concept.find_by_name('diagnosis')
    #      Location[:my_hospital] => Location.find_by_name('neno district hospital')
    def [](name)
      name = name.to_s.gsub('_', ' ')
      self.find_by_name(name)
    end
  end  

  def self.included(base)
    base.extend(ClassMethods)
    base.assign_scopes
  end
  
  def before_save
    super
    self.changed_by = User.current_user.id if self.attributes.has_key?("changed_by") and User.current_user != nil
    self.date_changed = Time.now if self.attributes.has_key?("date_changed")
  end

  def before_create
    super

    if !Person.migrated_datetime.to_s.empty?
      self.location_id = Person.migrated_location if self.attributes.has_key?("location_id")
      self.creator = Person.migrated_creator if self.attributes.has_key?("creator")
      self.date_created = Person.migrated_datetime if self.attributes.has_key?("date_created")
    else
      self.location_id = Location.current_health_center.id if self.attributes.has_key?("location_id") and (self.location_id.blank? || self.location_id == 0) and Location.current_health_center != nil
      self.creator = User.current_user.id if self.attributes.has_key?("creator") and (self.creator.blank? || self.creator == 0)and User.current_user != nil
      self.date_created = Time.now if self.attributes.has_key?("date_created")
    end

    self.uuid = ActiveRecord::Base.connection.select_one("SELECT UUID() as uuid")['uuid'] if self.attributes.has_key?("uuid")
  end
  
  # Override this
  def after_void(reason = nil)
  end
  
  def void(reason = "Voided through #{BART_VERSION}")
    unless voided?
      self.date_voided = Time.now
      self.voided = 1
      self.void_reason = reason
      self.voided_by = User.current_user.user_id unless User.current_user.nil?
      self.save
      self.after_void(reason)
    end    
  end
  
  def voided?
    self.attributes.has_key?("voided") ? voided == 1 : raise("Model does not support voiding")
  end 
  
  def add_location_obs
    obs = Observation.new()
    obs.person_id = self.patient_id
    obs.encounter_id = self.id
    obs.concept_id = ConceptName.find_by_name("WORKSTATION LOCATION").concept_id
    obs.value_text = Location.current_location.name
    obs.obs_datetime = self.encounter_datetime
    obs.save
  end
   
end
