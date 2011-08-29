class CreateLabs < ActiveRecord::Migration
  def self.up
    create_table :labs do |t|

      t.timestamps
    end
  end

  def self.down
    drop_table :labs
  end
end
