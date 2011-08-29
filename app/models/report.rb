module Report
    def self.generate_cohort_date_range(quarter = "", start_date = nil, end_date = nil)

    quarter_beginning   = start_date.to_date  rescue nil
    quarter_ending      = end_date.to_date    rescue nil
    quarter_end_dates   = []
    quarter_start_dates = []
    date_range          = [nil, nil]

    if(!quarter_beginning.nil? && !quarter_ending.nil?)
      date_range = [quarter_beginning, quarter_ending]
		elsif (!quarter.nil? && quarter == "Cumulative")
      quarter_beginning = Encounter.initial_encounter.encounter_datetime.to_date
      quarter_ending    = Date.today.to_date

      date_range        = [quarter_beginning, quarter_ending]
		elsif(!quarter.nil? && (/Q[1-4][\_\+\- ]\d\d\d\d/.match(quarter)))
			quarter, quarter_year = quarter.humanize.split(" ")

      quarter_start_dates = ["#{quarter_year}-01-01".to_date, "#{quarter_year}-04-01".to_date, "#{quarter_year}-07-01".to_date, "#{quarter_year}-10-01".to_date]
      quarter_end_dates   = ["#{quarter_year}-03-31".to_date, "#{quarter_year}-06-30".to_date, "#{quarter_year}-09-30".to_date, "#{quarter_year}-12-31".to_date]

      current_quarter   = (quarter.match(/\d+/).to_s.to_i - 1)
      quarter_beginning = quarter_start_dates[current_quarter]
      quarter_ending    = quarter_end_dates[current_quarter]

      date_range = [quarter_beginning, quarter_ending]

    end

    return date_range
  end

  def self.cohort_range(date)
    year = date.year
    if date >= "#{year}-01-01".to_date and date <= "#{year}-03-31".to_date
      quarter = "Q1 #{year}"
    elsif date >= "#{year}-04-01".to_date and date <= "#{year}-06-30".to_date
      quarter = "Q2 #{year}"
    elsif date >= "#{year}-07-01".to_date and date <= "#{year}-09-30".to_date
      quarter = "Q3 #{year}"
    elsif date >= "#{year}-10-01".to_date and date <= "#{year}-12-31".to_date
      quarter = "Q4 #{year}"
    end
    self.generate_cohort_date_range(quarter)
  end

  def self.generate_cohort_quarters(start_date, end_date)
    cohort_quarters   = []
    current_quarter   = ""
    quarter_end_dates = ["#{end_date.year}-03-31".to_date, "#{end_date.year}-06-30".to_date, "#{end_date.year}-09-30".to_date, "#{end_date.year}-12-31".to_date]

    quarter_end_dates.each_with_index do |quarter_end_date, quarter|
      (current_quarter = (quarter + 1) and break) if end_date < quarter_end_date
    end

    quarter_number  =  current_quarter
    cohort_quarters += ["Cumulative"]
    current_date    =  end_date

    begin
      cohort_quarters += ["Q#{quarter_number} #{current_date.year}"]
      (quarter_number > 1) ? quarter_number -= 1: (current_date = current_date - 1.year and quarter_number = 4)
    end while (current_date.year >= start_date.year)

    cohort_quarters
  end


=begin

"SELECT age,gender,count(*) AS total FROM 
            (SELECT age_group(p.birthdate,date(obs.obs_datetime),Date(p.date_created),p.birthdate_estimated) 
            as age,p.gender AS gender
            FROM `encounter` INNER JOIN obs ON obs.encounter_id=encounter.encounter_id
            INNER JOIN patient p ON p.patient_id=encounter.patient_id WHERE
            (encounter_datetime >= '#{start_date}' AND encounter_datetime <= '#{end_date}' 
            AND encounter_type=#{enc_type_id} AND obs.voided=0) GROUP BY encounter.patient_id 
            order by age) AS t group by t.age,t.gender"
=end




  def self.opd_diagnosis(start_date , end_date , groups = ['> 14 to < 20'] )
    age_groups = groups.map{|g|"'#{g}'"}
    concept = ConceptName.find_by_name("DIAGNOSIS").concept_id

=begin
    observations = Observation.find(:all,:joins => "INNER JOIN person p ON p.person_id = obs.person_id
                   INNER JOIN concept_name c ON obs.value_coded = c.concept_id",
                   :select => "value_coded diagnosis , 
                    (SELECT age_group(p.birthdate,LEFT(obs.obs_datetime,10),LEFT(p.date_created,10),p.birthdate_estimated) patient_groups",
                   :conditions => ["concept_id = ? AND obs_datetime >= ? AND obs_datetime <= ?",
                   concept , start_date.strftime('%Y-%m-%d 00:00:00') , end_date.strftime('%Y-%m-%d 23:59:59') ],
                   :group => "diagnosis HAVING patient_groups IN (#{age_groups.join(',')})",
                   :order => "diagnosis ASC")
=end

    observations = Observation.find_by_sql(["SELECT name diagnosis , 
age_group(p.birthdate,DATE(obs_datetime),DATE(p.date_created),p.birthdate_estimated) age_groups 
FROM `obs` 
INNER JOIN person p ON obs.person_id = obs.person_id
INNER JOIN concept_name c ON c.concept_name_id = obs.value_coded_name_id
WHERE (obs.concept_id=#{concept} 
AND obs_datetime >= '#{start_date.strftime('%Y-%m-%d 00:00:00')}'
AND obs_datetime <= '#{end_date.strftime('%Y-%m-%d 23:59:59')}' AND obs.voided = 0) 
GROUP BY diagnosis,age_groups
HAVING age_groups IN (#{age_groups.join(',')})
ORDER BY c.name ASC"])


    return {} if observations.blank?
    results = Hash.new(0)
    observations.map do | obs |
      results[obs.diagnosis] += 1
    end
    results
  end


  def self.opd_diagnosis_by_location(diagnosis , start_date , end_date , groups = ['> 14 to < 20'] )
    age_groups = groups.map{|g|"'#{g}'"}
    concept = ConceptName.find_by_name("DIAGNOSIS").concept_id

=begin
    observations = Observation.find(:all,:joins => "INNER JOIN person p ON p.person_id = obs.person_id
                   INNER JOIN concept_name c ON obs.value_coded = c.concept_id",
                   :select => "value_coded diagnosis , 
                    (SELECT age_group(p.birthdate,LEFT(obs.obs_datetime,10),LEFT(p.date_created,10),p.birthdate_estimated) patient_groups",
                   :conditions => ["concept_id = ? AND obs_datetime >= ? AND obs_datetime <= ?",
                   concept , start_date.strftime('%Y-%m-%d 00:00:00') , end_date.strftime('%Y-%m-%d 23:59:59') ],
                   :group => "diagnosis HAVING patient_groups IN (#{age_groups.join(',')})",
                   :order => "diagnosis ASC")
=end

    observations = Observation.find_by_sql(["SELECT name diagnosis , city_village village , 
age_group(p.birthdate,DATE(obs_datetime),DATE(p.date_created),p.birthdate_estimated) age_groups 
FROM `obs` 
INNER JOIN person p ON obs.person_id = obs.person_id
INNER JOIN concept_name c ON c.concept_name_id = obs.value_coded_name_id
INNER JOIN person_address pd ON obs.person_id = pd.person_id
WHERE (obs.concept_id=#{concept} 
AND obs_datetime >= '#{start_date.strftime('%Y-%m-%d 00:00:00')}'
AND obs_datetime <= '#{end_date.strftime('%Y-%m-%d 23:59:59')}' AND obs.voided = 0) 
GROUP BY diagnosis , village ,age_groups
HAVING age_groups IN (#{age_groups.join(',')}) AND diagnosis = ?
ORDER BY c.name ASC",diagnosis])


    return {} if observations.blank?
    results = Hash.new(0)
    observations.map do | obs |
      results["#{obs.village}::#{obs.diagnosis}"] += 1
    end
    results
  end

  def self.opd_diagnosis_plus_demographics(diagnosis , start_date , end_date , groups = ['> 14 to < 20'] )
    age_groups = groups.map{|g|"'#{g}'"}
    concept = ConceptName.find_by_name("DIAGNOSIS").concept_id
    attribute_type = PersonAttributeType.find_by_name("Cell Phone Number").id

    observations = Observation.find_by_sql(["SELECT 
p.person_id patient_id , pn.given_name first_name, pn.family_name last_name , p.birthdate, 
LEFT(obs.obs_datetime,10) visit_date, p.gender , pa.value phone_number , cn.name diagnosis,
age(p.birthdate, LEFT(obs_datetime,10),LEFT(p.date_created,10), p.birthdate_estimated) visit_age,
age(p.birthdate, current_date, current_date, p.birthdate_estimated) current_age, 
age_group(p.birthdate, LEFT(obs_datetime,10),LEFT(p.date_created,10), p.birthdate_estimated) age_groups, 
pd.city_village address, (SELECT address2 FROM person_address i WHERE i.person_id = p.person_id limit 1) landmark
FROM `obs`
INNER JOIN concept_name cn ON obs.value_coded_name_id = cn.concept_name_id
INNER JOIN person p ON obs.person_id = p.person_id
INNER JOIN person_attribute pa ON p.person_id = pa.person_id
INNER JOIN person_name pn ON p.person_id = pn.person_id
INNER JOIN person_address pd ON p.person_id = pd.person_id
WHERE (obs.concept_id = ? AND obs.obs_datetime >= ? AND obs.obs_datetime <= ? AND pa.person_attribute_type_id = ?) 
GROUP BY first_name,last_name,birthdate,gender,visit_date,value_coded_name_id
HAVING age_groups IN (#{age_groups.join(',')}) AND diagnosis = ?
ORDER BY age_groups DESC",concept , start_date.strftime('%Y-%m-%d 00:00:00'),
end_date.strftime('%Y-%m-%d 23:59:59'),attribute_type,diagnosis])

    return {} if observations.blank?
    results = Hash.new()
    count = 0
    observations.map do | obs |
      results["#{obs.patient_id}:#{obs.visit_date}"][:diagnosis] << obs.diagnosis unless results["#{obs.patient_id}:#{obs.visit_date}"].blank?
      results["#{obs.patient_id}:#{obs.visit_date}"] = {
                            :name => "#{obs.first_name} #{obs.last_name}",
                            :birthdate => obs.birthdate ,
                            :visit_date => obs.visit_date,
                            :visit_age => obs.visit_age,
                            :current_age => obs.current_age,
                            :phone_number => obs.phone_number,
                            :diagnosis => [obs.diagnosis]  ,
                            :age_group => obs.age_groups,
                            :address => obs.address
                          } if results["#{obs.patient_id}:#{obs.visit_date}"].blank?
    end
    results
  end


  def self.opd_disaggregated_diagnosis(start_date , end_date , groups = ['> 14 to < 20'] )
    age_groups = groups.map{|g|"'#{g}'"}
    concept = ConceptName.find_by_name("DIAGNOSIS").concept_id

    observations = Observation.find_by_sql(["SELECT p.person_id patient_id , p.gender gender , name diagnosis ,  
age_group(p.birthdate,DATE(obs_datetime),DATE(p.date_created),p.birthdate_estimated) age_groups
FROM `obs` 
INNER JOIN person p ON obs.person_id = p.person_id
INNER JOIN concept_name c ON c.concept_name_id = obs.value_coded_name_id
WHERE (obs.concept_id=#{concept} 
AND obs_datetime >= '#{start_date.strftime('%Y-%m-%d 00:00:00')}'
AND obs_datetime <= '#{end_date.strftime('%Y-%m-%d 23:59:59')}' AND obs.voided = 0) 
GROUP BY patient_id , age_groups , diagnosis 
HAVING age_groups IN (#{age_groups.join(',')})
ORDER BY diagnosis ASC"])


    return {} if observations.blank?
    results = Hash.new()
    observations.map do | obs |
      results[obs.diagnosis] = {obs.gender => {
                                 :less_than_six_months => 0,
                                 :six_months_to_five_years => 0,
                                 :five_years_to_fourteen_years => 0,
                                 :over_fourteen_years => 0 
                               }} if results[obs.diagnosis].blank?

     if results[obs.diagnosis][obs.gender].blank?
       results[obs.diagnosis] = {obs.gender => {
                                  :less_than_six_months => 0,
                                  :six_months_to_five_years => 0,
                                  :five_years_to_fourteen_years => 0,
                                  :over_fourteen_years => 0 
                                }} 
     end 


     case obs.age_groups
        when "< 6 months" 
          results[obs.diagnosis][obs.gender][:less_than_six_months]+=1
        when "6 months to < 1 yr" , "1 to < 5"
          results[obs.diagnosis][obs.gender][:six_months_to_five_years]+=1
        when "5 to 14"
          results[obs.diagnosis][obs.gender][:five_years_to_fourteen_years]+=1
        else
          results[obs.diagnosis][obs.gender][:over_fourteen_years]+=1
      end
    
    end
    results
  end

  def self.opd_referrals(start_date , end_date)
    concept = ConceptName.find_by_name("REFERRAL CLINIC IF REFERRED").concept_id

    observations = Observation.find_by_sql(["SELECT value_text clinic , count(*) total
FROM `obs` 
INNER JOIN concept_name c ON c.concept_name_id = obs.concept_id
WHERE (obs.concept_id=#{concept} 
AND obs_datetime >= '#{start_date.strftime('%Y-%m-%d 00:00:00')}'
AND obs_datetime <= '#{end_date.strftime('%Y-%m-%d 23:59:59')}' AND obs.voided = 0) 
GROUP BY clinic
ORDER BY clinic ASC"])


    return {} if observations.blank?
    results = Hash.new()
    observations.map do | obs |
      results[obs.clinic] = 1
    end
    results
  end

end
