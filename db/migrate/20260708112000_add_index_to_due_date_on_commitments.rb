class AddIndexToDueDateOnCommitments < ActiveRecord::Migration[8.0]
  def change
    add_index :commitments, :due_date
  end
end
