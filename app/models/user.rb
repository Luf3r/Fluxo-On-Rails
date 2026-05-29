class User < ApplicationRecord
  SUPPORTED_CURRENCIES = %w[BRL USD EUR].freeze
  SUPPORTED_LOCALES = I18n.available_locales.map(&:to_s).freeze

  # Include default devise modules. Others available are:
  # :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :confirmable

  validates :name, :currency, presence: true
  validates :currency, inclusion: { in: SUPPORTED_CURRENCIES }
  validates :preferred_locale, presence: true, inclusion: { in: SUPPORTED_LOCALES }

  def after_confirmation
    update_column(:email_verified_at, confirmed_at)
  end
end
