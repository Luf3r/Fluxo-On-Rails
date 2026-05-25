# spec/models/tag_spec.rb
require "rails_helper"

RSpec.describe Tag, type: :model do
  it { should belong_to(:user) }
  it { should have_many(:transaction_tags).dependent(:destroy) }
  it { should have_many(:transactions).through(:transaction_tags) }

  it { should validate_presence_of(:name) }

  describe "uniqueness" do
    let(:user) { create(:user) }

    it "rejects duplicate tag name for same user" do
      create(:tag, user: user, name: "urgente")
      expect(build(:tag, user: user, name: "urgente")).not_to be_valid
    end

    it "allows same tag name for different users" do
      create(:tag, user: create(:user), name: "urgente")
      expect(build(:tag, user: create(:user), name: "urgente")).to be_valid
    end

    it "normalizes names to lowercase" do
      tag = create(:tag, user: user, name: "URGENTE")
      expect(tag.name).to eq("urgente")
    end
  end

  describe "auto-creation" do
    let(:user)    { create(:user) }
    let(:account) { create(:account, user: user) }
    let(:tx)      { create(:transaction, :expense, account: account) }

    it "creates a tag if it does not exist when assigning to transaction" do
      expect {
        tx.tag_names = [ "nova-tag" ]
        tx.save!
      }.to change(Tag, :count).by(1)
    end

    it "reuses existing tag when assigning the same name" do
      existing = create(:tag, user: user, name: "recorrente")
      expect {
        tx.tag_names = [ "recorrente" ]
        tx.save!
      }.not_to change(Tag, :count)
      expect(tx.tags).to include(existing)
    end
  end
end
