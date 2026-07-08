class AddDueDateToCommitments < ActiveRecord::Migration[8.0]
  def change
    add_column :commitments, :due_date, :date
  end
end
