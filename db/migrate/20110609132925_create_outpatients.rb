class CreateOutpatients < ActiveRecord::Migration
  def self.up
    create_table :outpatients do |t|

      t.timestamps
    end
  end

  def self.down
    drop_table :outpatients
  end
end
