class User < ApplicationRecord
  SUPPORTED_CURRENCIES = %w[BRL USD EUR].freeze

  # Include default devise modules. Others available are:
  # :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :confirmable

  validates :name, :currency, presence: true
  validates :currency, inclusion: { in: SUPPORTED_CURRENCIES }

  def after_confirmation
    update_column(:email_verified_at, confirmed_at)
  end
end
