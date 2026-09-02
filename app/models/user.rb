# frozen_string_literal: true

class User < ApplicationRecord
  has_secure_password

  has_many :commitments, dependent: :destroy

  before_validation :normalize_email
  before_validation :normalize_username

  validates :email, presence: true, uniqueness: true
  validates :username,
            presence: true,
            uniqueness: true,
            format: { with: /\A[a-z0-9_]+\z/ },
            length: { in: 3..30 }
  validates :password, password_complexity: true
  validates :password_confirmation, presence: true, on: :create

  validates :monthly_income,
            numericality: { greater_than_or_equal_to: 0 },
            allow_nil: true

  validates :savings,
            numericality: { greater_than_or_equal_to: 0 },
            allow_nil: true

  validates :protected_savings,
            numericality: { greater_than_or_equal_to: 0 },
            allow_nil: true

  validate :valid_currency?

  private

  def normalize_email
    self.email = email.strip.downcase if email.present?
  end

  def normalize_username
    self.username = username.strip.downcase if username.present?
  end

  def valid_currency?
    return if currency.blank? || Money::Currency.find(currency)

    errors.add(:currency, "#{currency} is not a valid currency")
  end
end
