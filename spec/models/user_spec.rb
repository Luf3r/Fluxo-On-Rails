require "rails_helper"

RSpec.describe User, type: :model do
  describe "validations" do
    it "requires a name" do
      user = build(:user, name: nil)

      expect(user).not_to be_valid
      expect(user.errors[:name]).to be_present
    end

    it "requires an email" do
      user = build(:user, email: nil)

      expect(user).not_to be_valid
      expect(user.errors[:email]).to be_present
    end

    it "requires a password" do
      user = build(:user, password: nil)

      expect(user).not_to be_valid
      expect(user.errors[:password]).to be_present
    end

    it "requires a unique email" do
      create(:user, email: "ana@example.com")
      user = build(:user, email: "ana@example.com")

      expect(user).not_to be_valid
      expect(user.errors[:email]).to be_present
    end

    it "requires a currency" do
      user = build(:user, currency: nil)

      expect(user).not_to be_valid
      expect(user.errors[:currency]).to be_present
    end

    it "rejects unknown currencies" do
      user = build(:user, currency: "XYZ")

      expect(user).not_to be_valid
      expect(user.errors[:currency]).to be_present
    end

    it "accepts supported currencies" do
      User::SUPPORTED_CURRENCIES.each do |currency|
        expect(build(:user, currency: currency)).to be_valid
      end
    end

    it "uses BRL as the factory default currency" do
      user = build(:user)

      expect(user.currency).to eq("BRL")
    end

    it "normalizes email case and whitespace through Devise" do
      user = create(:user, email: "  ANA@EXAMPLE.COM  ")

      expect(user.email).to eq("ana@example.com")
    end
  end

  describe "Devise modules" do
    it "uses database authentication, registration, recovery, rememberable sessions, validation, and confirmation" do
      expect(described_class.devise_modules).to include(
        :database_authenticatable,
        :registerable,
        :recoverable,
        :rememberable,
        :validatable,
        :confirmable
      )
    end
  end

  describe "email verification parity field" do
    it "stores avatar URL and email verification timestamp" do
      verified_at = Time.current

      user = create(
        :user,
        avatar_url: "https://example.com/avatar.png",
        email_verified_at: verified_at
      )

      expect(user.reload.avatar_url).to eq("https://example.com/avatar.png")
      expect(user.email_verified_at.to_i).to eq(verified_at.to_i)
    end

    it "stores email_verified_at when set" do
      user = create(:user, email_verified_at: nil)

      user.update!(email_verified_at: Time.current)

      expect(user.reload.email_verified_at).not_to be_nil
    end

    it "is nil by default" do
      user = create(:user, email_verified_at: nil)

      expect(user.email_verified_at).to be_nil
    end
  end
end
