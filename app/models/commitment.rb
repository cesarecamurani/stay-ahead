# frozen_string_literal: true

class Commitment < ApplicationRecord
  belongs_to :user

  enum :category, {
    obligation: 0,   # rent, mortgage, essential fixed costs
    debt: 1,         # loans, installments, credit repayments
    service: 2,      # subscriptions, insurance
    investment: 3    # pension, funds, investing flows
  }, validate: true

  enum :status, {
    scheduled: 0,
    active: 1,
    paused: 2,
    completed: 3,
    cancelled: 4
  }, validate: true

  enum :recurrence, {
    one_time: 0,
    weekly: 1,
    monthly: 2,
    quarterly: 3,
    yearly: 4
  }, validate: true

  before_validation :set_initial_status, on: :create
  before_validation :calculate_end_date, on: :create

  scope :ready_to_activate, -> { scheduled.where(start_date: ..Date.current) }
  scope :ready_to_complete, -> do
    active
      .where.not(end_date: nil)
      .where(end_date: ..Date.current)
  end

  validates :name, presence: true
  validates :category, presence: true
  validates :recurrence, presence: true
  validates :status, presence: true
  validates :interest_rate, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :duration_months, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :start_date, presence: true
  validates :end_date, comparison: { greater_than: :start_date }, allow_nil: true, if: -> { start_date.present? }

  def set_initial_status
    return if start_date.blank?

    self.status = start_date <= Date.current ? :active : :scheduled
  end

  def calculate_end_date
    return if duration_months.blank? || start_date.blank?

    self.end_date ||= start_date + duration_months.months
  end

  def pause!
    transition_to!(:paused, from: %i[active])
  end

  def cancel!
    transition_to!(:cancelled, from: %i[scheduled active paused])
  end

  def resume!
    transition_to!(:active, from: %i[paused])
  end

  def activate!
    if start_date.blank?
      errors.add(:start_date, "cannot be blank")
      return false
    end

    if start_date > Date.current
      errors.add(:start_date, "cannot be in the future")
      return false
    end

    transition_to!(:active, from: %i[scheduled])
  end

  def complete!
    if end_date.blank?
      errors.add(:end_date, "cannot be blank")
      return false
    end

    if end_date > Date.current
      errors.add(:end_date, "cannot be in the future")
      return false
    end

    transition_to!(:completed, from: %i[active])
  end

  private

  def transition_to!(target_status, from:)
    unless persisted?
      errors.add(:status, "cannot transition a new commitment")

      return false
    end

    unless from.include?(status.to_sym)
      errors.add(:status, "cannot transition from #{status} to #{target_status}")

      return false
    end

    update(status: target_status)
  end
end
