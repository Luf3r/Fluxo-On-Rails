# frozen_string_literal: true

class Category < ApplicationRecord
  CATEGORY_TYPES = %w[expense income both].freeze
  DEFAULTS = [
    { name: "Outros", category_type: "both" },
    { name: "Moradia", category_type: "expense" },
    { name: "Mercado", category_type: "expense" },
    { name: "Transporte", category_type: "expense" },
    { name: "Saude", category_type: "expense" },
    { name: "Lazer", category_type: "expense" },
    { name: "Salario", category_type: "income" },
    { name: "Freelance", category_type: "income" }
  ].freeze
  SYSTEM_NAME_KEYS = {
    "Outros" => "other",
    "Moradia" => "housing",
    "Mercado" => "groceries",
    "Transporte" => "transport",
    "Saude" => "health",
    "Lazer" => "leisure",
    "Salario" => "salary",
    "Freelance" => "freelance"
  }.freeze

  belongs_to :user, optional: true
  belongs_to :parent, class_name: "Category", optional: true
  has_many :transactions
  has_many :sub_categories, class_name: "Category", foreign_key: :parent_id, inverse_of: :parent, dependent: :destroy

  before_destroy :protect_system_category
  before_destroy :move_transactions_to_fallback

  validates :name, presence: true
  validates :category_type, inclusion: { in: CATEGORY_TYPES }
  validates :budget_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :name, uniqueness: { scope: :user_id, case_sensitive: false }
  validate :system_category_has_no_user
  validate :custom_category_has_user
  validate :parent_is_not_self
  validate :parent_is_top_level
  validate :parent_is_accessible
  validate :parent_has_no_transactions
  validate :category_with_children_cannot_be_child
  validate :category_type_matches_existing_transactions

  scope :system, -> { where(system: true) }
  scope :custom, -> { where(system: false) }
  scope :for_user, ->(user) { where(user: user).or(system) }
  scope :leaf, -> { where.missing(:sub_categories) }

  def self.options_for_user(user)
    for_user(user).order(system: :desc, name: :asc)
  end

  def transaction_compatible?(transaction_type)
    category_type == "both" || category_type == transaction_type.to_s
  end

  def display_name
    return name unless system?

    translation_key = SYSTEM_NAME_KEYS[name]
    return name if translation_key.blank?

    I18n.t("finance.categories.system_names.#{translation_key}", default: name)
  end

  private

  def system_category_has_no_user
    errors.add(:user, :present) if system? && user.present?
  end

  def custom_category_has_user
    errors.add(:user, :blank) if !system? && user.blank?
  end

  def parent_is_not_self
    return if parent.blank? || id.blank? || parent_id != id

    errors.add(:parent, :invalid)
  end

  def parent_is_top_level
    return if parent.blank? || parent.parent_id.blank?

    errors.add(:parent, :invalid)
  end

  def parent_is_accessible
    return if parent.blank?
    return if parent.system?
    return if user_id.present? && parent.user_id == user_id

    errors.add(:parent, :invalid)
  end

  def parent_has_no_transactions
    return if parent.blank? || !parent.transactions.exists?

    errors.add(:parent, :invalid)
  end

  def category_with_children_cannot_be_child
    return if parent.blank? || !sub_categories.exists?

    errors.add(:parent, :invalid)
  end

  def category_type_matches_existing_transactions
    return if category_type == "both"
    return unless transactions.where.not(transaction_type: [ category_type, "transfer" ]).exists?

    errors.add(:category_type, :invalid)
  end

  def protect_system_category
    return unless system?

    errors.add(:base, :restrict_dependent_destroy)
    throw :abort
  end

  def move_transactions_to_fallback
    return if transactions.none?

    fallback = Category.system.find_by(name: "Outros")
    unless fallback && !fallback.sub_categories.exists?
      errors.add(:base, :restrict_dependent_destroy)
      throw :abort
    end

    transactions.update_all(category_id: fallback.id, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
  end
end
