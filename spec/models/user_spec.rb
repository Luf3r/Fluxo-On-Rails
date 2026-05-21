require 'rails_helper'

RSpec.describe User, type: :model do
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

  it "requires a currency" do
    user = build(:user, currency: nil)

    expect(user).not_to be_valid
    expect(user.errors[:currency]).to be_present
  end

  it "accepts only supported currencies" do
    user = build(:user, currency: "GBP")

    expect(user).not_to be_valid
    expect(user.errors[:currency]).to be_present
  end

  it "requires a unique email" do
    create(:user, email: "duplicate@example.com")
    user = build(:user, email: "duplicate@example.com")

    expect(user).not_to be_valid
    expect(user.errors[:email]).to be_present
  end

  it "defaults currency to BRL" do
    user = User.new

    expect(user.currency).to eq("BRL")
  end

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
end
