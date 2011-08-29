class NationalId < ActiveRecord::Base
  set_table_name "national_id"
  named_scope :active, :conditions => ['assigned = 0']

  def self.next_id(patient_id = nil)
    id = self.active.find(:first) rescue nil
    return if id.blank?
    return id.national_id if patient_id.blank?
    id.assigned = true
    id.eds = true
    id.date_issued = Time.now()
    id.creator = User.current_user.id
    id.save
    return id.national_id
  end

  def self.next_ids_available_label(location_name = nil)
    id = self.active.find(:first,:order => "id DESC")
    return "" if id.blank?
    national_id = id.national_id[0..2] + "-" + id.national_id[3..-1]
    label = ZebraPrinter::StandardLabel.new
    label.draw_barcode(40, 210, 0, 1, 5, 10, 70, false, "#{id.national_id}")
    label.draw_text("Name:", 40, 30, 0, 2, 2, 2, false)
    label.draw_text("#{national_id}  dd__/mm__/____  (F/M)", 40, 110, 0, 2, 2, 2, false)
    label.draw_text("TA:", 40, 160, 0, 2, 2, 2, false)
    id.assigned = true
    id.date_issued = Time.now()
    id.issued_to = location_name
    id.creator = User.current_user.id
    id.save
    label.print(1)
  end

end
