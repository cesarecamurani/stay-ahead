# frozen_string_literal: true

class AddProtectedSavingsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :protected_savings, :decimal, precision: 10, scale: 2
  end
end
