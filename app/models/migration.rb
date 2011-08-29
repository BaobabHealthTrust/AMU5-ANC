class Migration

  def self.get_patient_demographics_from_csv_and_create_patient

      person_id  = 0
      patient_id  = 1
      arv_number = 2
      national_id = 3
      first_name  = 4
      last_name   = 5
      sex = 6
      birth_date  = 7
      birthdate_estimated = 8
      occupation = 9
      cell_phone_number  = 10
      home_phone_number  = 11
      office_phone_number =12
      physical_adress =13
      landmark  = 14
      city_village = 15
      traditional_authority = 16
      patient_voided = 17
      creator = 18
      void_reason = 19
      change_by = 20
      date_created = 21

      person = {}

      person = { "person"=>{ "occupation"=>"",
                        "age_estimate"=>"",
                        "cell_phone_number"=>"",
                        "birth_month"=>"",
                        "addresses"=>{ "address2"=>"",
                                       "city_village"=>"",
                                       "county_district"=>""
                                      },
                        "gender"=>"",
                        "patient_id"=>"",
                        "birth_day"=>"",
                        "names"=>{"family_name"=>"",
                                  "given_name"=>""
                                 },
                        "birth_year"=>""
                       },
            "relation"=>"",
            "identifier"=>""
           }

      i = 0
      csv_url = RAILS_ROOT + '/patient-300.csv'
      FasterCSV.foreach("#{csv_url}", :quote_char => '"', :col_sep =>',', :row_sep =>:auto) do |row|

        person = {}
        person["person"] = {}
        person["person"]["occupation"] = row[occupation].to_s rescue nil
        person["person"]["age_estimate"] = row[birthdate_estimated].to_s rescue nil
        person["person"]["cell_phone_number"] = row[cell_phone_number].to_s rescue nil

        person["person"]["birth_month"] = row[birth_date].to_date.month rescue nil
        person["person"]["birth_year"] = row[birth_date].to_date.year rescue 2010
        person["person"]["birth_day"] = row[birth_date].to_date.day rescue nil

        person["person"]["addresses"] = {}
        person["person"]["addresses"]["address2"] = row[landmark].to_s rescue nil
        person["person"]["addresses"]["city_village"] = row[city_village].to_s rescue nil
        person["person"]["addresses"]["county_district"] = row[traditional_authority].to_s rescue nil

        person["person"]["gender"] = row[sex].to_s rescue nil
        person["person"]["patient_id"] = row[patient_id].to_s rescue nil


        person["person"]["names"] = {}
        person["person"]["names"]["family_name"] = row[last_name].to_s rescue nil
        person["person"]["names"]["given_name"] = row[first_name].to_s rescue nil

        person_arv_number  = row[arv_number].to_s rescue nil
        person_national_id = row[national_id].to_s rescue nil

        Person.migrated_datetime = row[date_created].to_datetime.strftime("%Y-%m-%d %H:%M:%S").to_s rescue nil
        Person.migrated_creator  = row[creator].to_s
        ActiveRecord::Base.connection.execute('SET foreign_key_checks = 0')
        person = Migration.create_patient_from_migrated_data(person["person"])
        ActiveRecord::Base.connection.execute('SET foreign_key_checks = 1')
      end
  end

 def self.create_patient_from_migrated_data(params)
    address_params = params["addresses"]
    names_params = params["names"]
    patient_params = params["patient"]
    params_to_process = params.reject{|key,value| key.match(/addresses|patient|names|relation|cell_phone_number|home_phone_number|office_phone_number/) }
    birthday_params = params_to_process.reject{|key,value| key.match(/gender/) }
    person_params = params_to_process.reject{|key,value| key.match(/birth_|age_estimate|occupation/) }

    #person = Person.create(person_params)

    uuid = ActiveRecord::Base.connection.select_one("SELECT UUID() as uuid")['uuid']
    migrated_datetime = Person.migrated_datetime.to_s
    migrated_creator = Person.migrated_creator
    sql = "INSERT INTO `person` (`person_id`,`voided`, `birthdate`, `changed_by`, `birthdate_estimated`, `creator`, `uuid`, `gender`, `voided_by`, `dead`, `date_voided`, `void_reason`, `death_date`, `date_changed`, `cause_of_death`, `date_created`)
                                  VALUES(#{params['patient_id']},0, NULL, 1, 0, '#{migrated_creator}', '#{uuid}', '#{params['gender']}', NULL, 0, NULL, NULL, NULL, '2011-07-05 09:24:16', NULL, '#{migrated_datetime}')"

    ActiveRecord::Base.connection.execute(sql) rescue nil
    person = Person.find(params["patient_id"])  rescue nil

    if birthday_params["birth_year"] == "Unknown"
      person.set_birthdate_by_age(birthday_params["age_estimate"],self.session_datetime || Date.today)
    else
      person.set_birthdate(birthday_params["birth_year"], birthday_params["birth_month"], birthday_params["birth_day"])
    end
    person.save
    person.names.create(names_params)
    person.addresses.create(address_params)

    person.person_attributes.create(
      :person_attribute_type_id => PersonAttributeType.find_by_name("Occupation").person_attribute_type_id,
      :value => params["occupation"]) unless params["occupation"].blank? rescue nil

    person.person_attributes.create(
      :person_attribute_type_id => PersonAttributeType.find_by_name("Cell Phone Number").person_attribute_type_id,
      :value => params["cell_phone_number"]) unless params["cell_phone_number"].blank? rescue nil

    person.person_attributes.create(
      :person_attribute_type_id => PersonAttributeType.find_by_name("Office Phone Number").person_attribute_type_id,
      :value => params["office_phone_number"]) unless params["office_phone_number"].blank? rescue nil

    person.person_attributes.create(
      :person_attribute_type_id => PersonAttributeType.find_by_name("Home Phone Number").person_attribute_type_id,
      :value => params["home_phone_number"]) unless params["home_phone_number"].blank? rescue nil

# TODO handle the birthplace attribute

      patient = person.create_patient rescue nil

      patient_params["identifiers"].each{|identifier_type_name, identifier|

        identifier_type = PatientIdentifierType.find_by_name(identifier_type_name) || PatientIdentifierType.find_by_name("Unknown id")
        patient.patient_identifiers.create("identifier" => identifier, "identifier_type" => identifier_type.patient_identifier_type_id)
      } if patient_params["identifiers"] rescue nil

      # This might actually be a national id, but currently we wouldn't know
      #patient.patient_identifiers.create("identifier" => patient_params["identifier"], "identifier_type" => PatientIdentifierType.find_by_name("Unknown id")) unless params["identifier"].blank?

    return person
  end

  def self.get_user_data_from_csv_and_create_user()
        user_id = 0
        system_id = 1
        username = 2
        first_name = 3
        middle_name = 4
        last_name = 5
        password = 6
        salt = 7
        secret_Question = 8
        secret_Answer = 9
        creator = 10
        date_created = 11
        changed_by = 12
        date_changed = 13
        voided = 14
        voided_by = 15
        date_voided = 16
        void_Reason = 17

      csv_url = RAILS_ROOT + '/user-300.csv'
      FasterCSV.foreach("#{csv_url}", :quote_char => '"', :col_sep =>',', :row_sep =>:auto) do |user|
        existing_user = User.find(:first, :conditions => {:username => params[:user][:username]}) rescue nil
        if existing_user
          next
        end

       # person = Person.create()

        params={}
        params[:person_name] = {"family_name" => user[last_name], "middle_name" => user[middle_name],"given_name" => user[first_name]}

        #person.names.create(params[:person_name])

        date_voided = user[date_voided].to_datetime.strftime('%Y-%m-%d %H:%M:%S') rescue ''
        sql = "INSERT INTO users (user_id, system_id, username, password, salt, secret_question, secret_answer, creator, date_created, changed_by, date_changed, person_id, retired, retired_by, date_retired, retire_reason, uuid)
               VALUES(#{user[user_id]}, '#{user[system_id]}', '#{user[username]}', '#{user[password]}', '#{user[salt]}', '#{user[secret_Question]}', '#{user[secret_Answer]}', #{user[creator]}, '#{user[date_created].to_datetime.strftime('%Y-%m-%d %H:%M:%S')}', #{user[changed_by]}, '#{user[date_changed].to_datetime.strftime('%Y-%m-%d %H:%M:%S')}', NULL, #{user[voided]}, '#{user[voided_by]}', '#{date_voided}', NULL, '')"
        ActiveRecord::Base.connection.execute('SET foreign_key_checks = 0')
        ActiveRecord::Base.connection.execute(sql)
        ActiveRecord::Base.connection.execute('SET foreign_key_checks = 1')
      end
  end

  def self.get_user_identifier_from_csv_and_create_user
        patient_id = 0
        identifier_no = 1
        identifier_type = 2
        preferred = 3
        location_id = 4
        creator = 5
        date_created = 6
        voided = 7
        voided_by = 8
        date_voided = 9
        void_reason = 10

      csv_url = RAILS_ROOT + '/identifier-300.csv'
      FasterCSV.foreach("#{csv_url}", :quote_char => '"', :col_sep =>',', :row_sep =>:auto, :headers => true) do |identifier|

      date_create = identifier[date_created].to_datetime.strftime('%Y-%m-%d %H:%M:%S') rescue nil
      date_voide =  identifier[date_voided].to_datetime.strftime('%Y-%m-%d %H:%M:%S') rescue nil

      if identifier[identifier_type].gsub('_',' ').to_s == "Arv national id"
         identifier[identifier_type] = "ARV Number"
      end
      identifier_type_id = PatientIdentifierType.find_by_name(identifier[identifier_type].gsub('_',' ')).id rescue nil

      if identifier_type_id == nil
         next
      end

      uuid = ActiveRecord::Base.connection.select_one("SELECT UUID() as uuid")['uuid']
      sql = "INSERT INTO `patient_identifier` (`patient_id`, `identifier`, `identifier_type`, `preferred`, `location_id`, `creator`, `date_created`, `voided`, `voided_by`, `date_voided`, `void_reason`, `uuid`)
             VALUES('#{identifier[patient_id]}', '#{identifier[identifier_no]}', '#{identifier_type_id}', '#{identifier[preferred]}', '#{identifier[location_id]}', '#{identifier[creator]}', '#{date_create}', #{identifier[voided]}, '#{identifier[voided_by]}', '#{date_voide}', '#{identifier[void_reason]}', '#{identifier[identifier_no]}')"

        ActiveRecord::Base.connection.execute('SET foreign_key_checks = 0')
        ActiveRecord::Base.connection.execute(sql)
        ActiveRecord::Base.connection.execute('SET foreign_key_checks = 1')
      end
  end
end
