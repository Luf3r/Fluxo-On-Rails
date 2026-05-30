# spec/models/category_spec.rb
require "rails_helper"

RSpec.describe Category, type: :model do
  it { should belong_to(:user).optional }  # system categories have no user
  it { should belong_to(:parent).class_name("Category").optional }
  it { should have_many(:transactions) }
  it { should have_many(:sub_categories).class_name("Category").dependent(:destroy) }

  it { should validate_presence_of(:name) }
  it { should validate_inclusion_of(:category_type).in_array(%w[expense income both]) }
  it { should validate_numericality_of(:budget_amount).is_greater_than_or_equal_to(0).allow_nil }

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

  describe "two-level hierarchy" do
    let(:user) { create(:user) }
    let(:parent) { create(:category, user: user, name: "Casa") }

    it "allows one child level under a parent category" do
      child = create(:category, user: user, parent: parent, name: "Aluguel")
      expect(parent.sub_categories).to include(child)
    end

    it "rejects nesting below parent and child" do
      child = create(:category, user: user, parent: parent, name: "Aluguel")
      grandchild = build(:category, user: user, parent: child, name: "Contrato")

      expect(grandchild).not_to be_valid
      expect(grandchild.errors[:parent]).to be_present
    end

    it "requires sub-category parent to belong to the same user or be a system category" do
      other_parent = create(:category, user: create(:user), name: "Other private parent")
      child = build(:category, user: user, parent: other_parent, name: "Invalid child")

      expect(child).not_to be_valid
      expect(child.errors[:parent]).to be_present
    end

    it "allows transactions on parent categories that do not have children" do
      tx = build(:transaction, :expense, account: create(:account, user: user), category: parent)
      expect(tx).to be_valid
    end

    it "rejects transactions on categories that have children" do
      create(:category, user: user, parent: parent, name: "Aluguel")
      tx = build(:transaction, :expense, account: create(:account, user: user), category: parent)

      expect(tx).not_to be_valid
      expect(tx.errors[:category]).to be_present
    end
  end
end
