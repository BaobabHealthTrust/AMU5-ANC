class Property

  def self.clinic_appointment_limit(end_date = nil)
    encounter_type = EncounterType.find_by_name('APPOINTMENT')
    booked_dates = Hash.new(0)

    start_date = (end_date - 5.day)

    Observation.find(:all,
    :joins => "INNER JOIN encounter e USING(encounter_id)",
    :conditions => ["encounter_type = ? AND value_datetime IS NOT NULL
    AND (DATE(value_datetime) >= ? AND DATE(value_datetime) <= ?)",
    encounter_type.id,start_date,end_date]).map do | obs |
      booked_dates[obs.value_datetime.to_date]+=1
    end  

    return booked_dates
  end

end 
