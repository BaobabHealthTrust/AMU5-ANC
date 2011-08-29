class MigrationController < ApplicationController
      def migrate_user
          Migration.get_user_data_from_csv_and_create_user()
      end

      def migrate_patients
          Migration.get_patient_demographics_from_csv_and_create_patient
      end

      def identifier
          Migration.get_user_identifier_from_csv_and_create_user
      end
end
