class MakeStartDateNullableOnCommitments < ActiveRecord::Migration[8.0]
  def change
    change_column_null :commitments, :start_date, true
  end
end
