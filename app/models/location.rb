class Location < ActiveRecord::Base
  set_table_name "location"
  set_primary_key "location_id"
  include Openmrs

  cattr_accessor :current_location

  def site_id
    Location.current_health_center.location_id.to_s
  rescue 
    raise "The id for this location has not been set (#{Location.current_location.name}, #{Location.current_location.id})"   
  end

  # Looks for the most commonly used element in the database and sorts the results based on the first part of the string
  def self.most_common_program_locations(search)
    return (self.find_by_sql([
      "SELECT DISTINCT location.name AS name, location.location_id AS location_id \
       FROM location \
       INNER JOIN patient_program ON patient_program.location_id = location.location_id AND patient_program.voided = 0 \
       WHERE location.retired = 0 AND name LIKE ? \
       GROUP BY patient_program.location_id \
       ORDER BY INSTR(name, ?) ASC, COUNT(name) DESC, name ASC \
       LIMIT 10", 
       "%#{search}%","#{search}"]) + [self.current_health_center]).uniq
  end

  def self.most_common_locations(search)
    return (self.find_by_sql([
      "SELECT DISTINCT location.name AS name, location.location_id AS location_id \
       FROM location \
       WHERE location.retired = 0 AND name LIKE ? \
       ORDER BY name ASC \
       LIMIT 10", 
       "%#{search}%"])).uniq
  end

  def children
    return [] if self.name.match(/ - /)
    Location.find(:all, :conditions => ["name LIKE ?","%" + self.name + " - %"])
  end

  def parent
    return nil unless self.name.match(/(.*) - /)
    Location.find_by_name($1)
  end

  def site_name
    self.name.gsub(/ -.*/,"")
  end

  def related_locations_including_self
    if self.parent
      return self.parent.children + [self]
    else
      return self.children + [self]
    end
  end

  def related_to_location?(location)
    self.site_name == location.site_name
  end

  def self.current_health_center
    @@current_health_center ||= Location.find(GlobalProperty.find_by_property("current_health_center_id").property_value) rescue self.current_location
  end

  def self.current_arv_code
    current_health_center.neighborhood_cell rescue nil
  end
  
  def location_label
    return unless self.location_id
    label = ZebraPrinter::StandardLabel.new
    label.font_size = 2
    label.font_horizontal_multiplier = 2
    label.font_vertical_multiplier = 2
    label.left_margin = 50
    label.draw_barcode(50,180,0,1,5,15,120,false,"#{self.location_id}")
    label.draw_multi_text("#{self.name}")
    label.print(1)
  end

  def self.workstation_locations
      field_name = "name"

      sql = "SELECT *
             FROM location
             WHERE location_id IN (SELECT location_id
                          FROM location_tag_map
                          WHERE location_tag_id = (SELECT location_tag_id
                                 FROM location_tag
                                 WHERE name = 'Workstation Location'))
             ORDER BY name ASC"

      Location.find_by_sql(sql).collect{|name| name.send(field_name)} rescue []
  end

  def self.search(search_string, act)
      field_name = "name"
      if act == "delete"  || act == "print" then
          sql = "SELECT *
                 FROM location
                 WHERE location_id IN (SELECT location_id
                              FROM location_tag_map
                              WHERE location_tag_id = (SELECT location_tag_id
	                                   FROM location_tag
	                                   WHERE name = 'Workstation Location'))
                 ORDER BY name ASC"
      elsif act == "create" then
          sql = "SELECT *
                 FROM location
                 WHERE location_id NOT IN (SELECT location_id
                              FROM location_tag_map
                              WHERE location_tag_id = (SELECT location_tag_id
	                                   FROM location_tag
	                                   WHERE name = 'Workstation Location'))  AND name LIKE '%#{search_string}%'
                 ORDER BY name ASC"
      end
      self.find_by_sql(sql).collect{|name| name.send(field_name)}
  end

end
