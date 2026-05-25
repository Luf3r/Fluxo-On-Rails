# spec/models/category_spec.rb
require "rails_helper"

RSpec.describe Category, type: :model do
  it { should belong_to(:user).optional }  # system categories have no user
  it { should have_many(:transactions) }
  it { should have_many(:sub_categories).dependent(:destroy) }

  it { should validate_presence_of(:name) }
  it { should validate_inclusion_of(:category_type).in_array(%w[expense income both]) }

  describe "system categories" do
    it "cannot be destroyed" do
      system_cat = create(:category, :system)
      expect { system_cat.destroy }.not_to change(Category, :count)
      expect(system_cat.errors[:base]).to be_present
    end

    it "seeds default categories" do
      # After running db:seed, standard categories should exist
      Category::DEFAULTS.each do |attrs|
        expect(Category.exists?(name: attrs[:name], system: true)).to be(true),
          "Expected system category '#{attrs[:name]}' to exist after seed"
      end
    end
  end

  describe "custom categories" do
    let(:user) { create(:user) }

    it "can be created by a user" do
      cat = create(:category, user: user, name: "Viagens")
      expect(cat).to be_persisted
    end

    it "can be destroyed if no transactions are linked" do
      cat = create(:category, user: user)
      expect { cat.destroy }.to change(Category, :count).by(-1)
    end

    it "moves transactions to 'Outros' before destroying if transactions exist" do
      outros = create(:category, :system, name: "Outros")
      cat    = create(:category, user: user)
      tx     = create(:transaction, :expense, account: create(:account, user: user), category: cat)

      cat.destroy

      expect(tx.reload.category).to eq(outros)
      expect(Category.exists?(cat.id)).to be(false)
    end

    it "rejects deletion with transactions when 'Outros' is missing" do
      cat = create(:category, user: user)
      create(:transaction, :expense, account: create(:account, user: user), category: cat)

      expect { cat.destroy }
        .not_to change(Category, :count)
    end
  end

  describe "uniqueness per user" do
    let(:user) { create(:user) }

    it "allows same name for different users" do
      create(:category, user: user, name: "Custom")
      other_user = create(:user)
      expect(build(:category, user: other_user, name: "Custom")).to be_valid
    end

    it "rejects duplicate name for same user" do
      create(:category, user: user, name: "Duplicada")
      expect(build(:category, user: user, name: "Duplicada")).not_to be_valid
    end
  end
end