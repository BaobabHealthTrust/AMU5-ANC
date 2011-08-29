class Lab < ActiveRecord::Base
  set_table_name "map_lab_panel"

  def self.results(patient)
    patient_ids = patient.id_identifiers
    results = self.find_by_sql(["
SELECT * FROM Lab_Sample s
INNER JOIN Lab_Parameter p ON p.sample_id = s.sample_id
INNER JOIN codes_TestType c ON p.testtype = c.testtype
INNER JOIN (SELECT DISTINCT rec_id, short_name FROM map_lab_panel) m ON c.panel_id = m.rec_id
WHERE s.patientid IN (?)
AND s.deleteyn = 0
AND s.attribute = 'pass'
GROUP BY short_name ORDER BY m.short_name",patient_ids
    ]).collect do | result |
      [
        result.short_name,
        result.TestName,
        result.Range,
        result.TESTVALUE,
        result.TESTDATE
      ]
    end

    return if results.blank?
    results
  end

  def self.results_by_type(patient,type)
    patient_ids = patient.id_identifiers
    results_hash = {}
    results = self.find_by_sql(["
SELECT * FROM Lab_Sample s
INNER JOIN Lab_Parameter p ON p.sample_id = s.sample_id
INNER JOIN codes_TestType c ON p.testtype = c.testtype
INNER JOIN (SELECT DISTINCT rec_id, short_name FROM map_lab_panel) m ON c.panel_id = m.rec_id
WHERE s.patientid IN (?)
AND short_name = ?
AND s.deleteyn = 0
AND s.attribute = 'pass'
ORDER BY DATE(TESTDATE) DESC",patient_ids,type
    ]).collect do | result |
      test_date = result.TESTDATE.to_date rescue ''
      if results_hash[result.TestName].blank?
        results_hash["#{test_date}::#{result.TestName}"] = { "Range" => nil , "TestValue" => nil }
      end
      results_hash["#{test_date}::#{result.TestName}"] = { "Range" => result.Range , "TestValue" => result.TESTVALUE }
    end

    return if results_hash.blank?
    results_hash
  end

end
