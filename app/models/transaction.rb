# frozen_string_literal: true

class Transaction < ApplicationRecord
  TRANSACTION_TYPES = %w[income expense transfer].freeze
  STATUSES = %w[settled pending].freeze
  TRANSFER_DIRECTIONS = %w[outgoing incoming].freeze
  MAX_AMOUNT = BigDecimal("999999999999.99")

  attr_accessor :to_account_id

  belongs_to :account
  belongs_to :transfer_pair, class_name: "Transaction", optional: true

  enum :transaction_type, TRANSACTION_TYPES.index_with(&:itself), validate: true
  enum :status, STATUSES.index_with(&:itself), validate: true

  before_validation :assign_status_from_date

  validates :amount, :date, :transaction_type, presence: true
  validates :amount, numericality: { greater_than: 0, less_than_or_equal_to: MAX_AMOUNT }
  validates :transaction_type, inclusion: { in: TRANSACTION_TYPES }
  validates :status, inclusion: { in: STATUSES }
  validates :transfer_direction, inclusion: { in: TRANSFER_DIRECTIONS }, allow_nil: true

  scope :by_period, ->(start_date, end_date) {
    parsed_start_date = safe_parse_date(start_date)
    parsed_end_date = safe_parse_date(end_date)

    if parsed_start_date && parsed_end_date
      where(date: parsed_start_date..parsed_end_date)
    else
      all
    end
  }
  scope :search, ->(query) {
    sanitized_query = sanitize_sql_like(query.to_s)
    where("description ILIKE ?", "%#{sanitized_query}%")
  }
  scope :current_month, -> { where(date: Date.current.all_month) }
  scope :transfer_incoming, -> { transfer.where(transfer_direction: "incoming") }
  scope :transfer_outgoing, -> { transfer.where(transfer_direction: "outgoing") }

  def self.safe_parse_date(value)
    Date.iso8601(value.to_s)
  rescue ArgumentError, Date::Error
    nil
  end

  private

  def assign_status_from_date
    return if date.blank?

    self.status = date.future? ? "pending" : (status.presence || "settled")
  end
end
