# frozen_string_literal: true

class Commitment < ApplicationRecord
  belongs_to :user

  enum :category, {
    obligation: 0,   # rent, mortgage, essential fixed costs
    debt: 1,         # loans, installments, credit repayments
    service: 2,      # subscriptions, insurance
    investment: 3,   # pension, funds, investing flows
    savings: 4       # planned transfers into accessible savings
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
  after_create :add_amount_to_savings, if: :savings?

  scope :ready_to_activate, -> {
    scheduled
      .where.not(recurrence: :one_time)
      .where(start_date: ..Date.current)
  }

  scope :ready_to_complete, lambda {
    one_time = scheduled.where(recurrence: :one_time).where(due_date: ..Date.current)
    recurring = active
      .where.not(recurrence: :one_time)
      .where.not(end_date: nil)
      .where(end_date: ..Date.current)

    one_time.or(recurring)
  }

  validates :name, presence: true
  validates :category, presence: true
  validates :recurrence, presence: true
  validates :status, presence: true
  validates :interest_rate, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :duration_months, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true
  validates :amount, presence: true, numericality: { greater_than: 0 }

  validates :start_date, presence: true, unless: :one_time?
  validates :start_date, absence: true, if: :one_time?

  validates :due_date, presence: true, if: :one_time?
  validates :due_date, absence: true, unless: :one_time?

  validates :end_date, comparison: { greater_than: :start_date }, allow_nil: true, if: -> { start_date.present? }

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
    if one_time?
      errors.add(:recurrence, "cannot be activated")
      return false
    end

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
    date_attribute = one_time? ? :due_date : :end_date
    allowed_states = one_time? ? %i[scheduled] : %i[active]

    if completion_date.blank?
      errors.add(date_attribute, "cannot be blank")
      return false
    end

    if completion_date > Date.current
      errors.add(date_attribute, "cannot be in the future")
      return false
    end

    transition_to!(:completed, from: allowed_states)
  end

  private

  def add_amount_to_savings
    user.increment!(:savings, amount)
  end

  def set_initial_status
    return if activation_date.blank?

    self.status =
      if activation_date <= Date.current
        one_time? ? :completed : :active
      else
        :scheduled
      end
  end

  def calculate_end_date
    return if one_time?
    return if duration_months.blank?
    return if start_date.blank?

    self.end_date ||= start_date + duration_months.months
  end

  def activation_date
    one_time? ? due_date : start_date
  end

  def completion_date
    one_time? ? due_date : end_date
  end

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
