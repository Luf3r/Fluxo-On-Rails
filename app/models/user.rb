class User < ApplicationRecord
  SUPPORTED_CURRENCIES = %w[BRL USD EUR].freeze

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # email_verified_at is a product parity field; this phase does not enable Devise confirmable.

  validates :name, :currency, presence: true
  validates :currency, inclusion: { in: SUPPORTED_CURRENCIES }
end
