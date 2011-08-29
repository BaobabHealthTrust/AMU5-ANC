class CreateNationalIds < ActiveRecord::Migration
  def self.up
    create_table :national_ids do |t|

      t.timestamps
    end
  end

  def self.down
    drop_table :national_ids
  end
end
