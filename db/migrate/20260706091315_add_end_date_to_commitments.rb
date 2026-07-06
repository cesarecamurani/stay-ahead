class AddEndDateToCommitments < ActiveRecord::Migration[8.0]
  def change
    add_column :commitments, :end_date, :date, null: true
    add_index :commitments, :end_date
  end
end
