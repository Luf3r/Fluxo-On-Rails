# spec/models/category_spec.rb
require "rails_helper"

RSpec.describe Category, type: :model do
  it "belongs to a user association" do
    expect(described_class.reflect_on_association(:user).macro).to eq(:belongs_to)
  end
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
      Rails.application.load_seed

      Category::DEFAULTS.each do |attrs|
        expect(Category.exists?(name: attrs[:name], system: true)).to be(true),
          "Expected system category '#{attrs[:name]}' to exist after seed"
      end
    end

    it "uses localized display names" do
      category = build(:category, :system, name: "Mercado")

      I18n.with_locale(:en) do
        expect(category.display_name).to eq("Groceries")
      end

      I18n.with_locale(:"pt-BR") do
        expect(category.display_name).to eq("Mercado")
      end
    end
  end

  describe "custom categories" do
    let(:user) { create(:user) }

    it "can be created by a user" do
      cat = create(:category, user: user, name: "Viagens")
      expect(cat).to be_persisted
    end

    it "requires an owner for non-system categories" do
      category = build(:category, user: nil, system: false)

      expect(category).not_to be_valid
      expect(category.errors[:user]).to be_present
    end

    it "keeps user-provided display names in every locale" do
      category = build(:category, user: user, name: "Mercado pessoal")

      I18n.with_locale(:en) do
        expect(category.display_name).to eq("Mercado pessoal")
      end
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

    it "rejects deletion with transactions when the 'Outros' fallback is not a leaf category" do
      outros = create(:category, :system, name: "Outros")
      create(:category, user: user, parent: outros, name: "Outros detalhe")
      cat = create(:category, user: user)
      tx = create(:transaction, :expense, account: create(:account, user: user), category: cat)

      expect { cat.destroy }
        .not_to change(Category, :count)
      expect(tx.reload.category).to eq(cat)
    end

    it "rejects category type changes that would make existing transactions incompatible" do
      category = create(:category, :income, user: user)
      create(:transaction, :income, account: create(:account, user: user), category: category)

      category.category_type = "expense"

      expect(category).not_to be_valid
      expect(category.errors[:category_type]).to be_present
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

    it "rejects turning a category that already has children into a sub-category" do
      create(:category, user: user, parent: parent, name: "Aluguel")
      new_parent = create(:category, user: user, name: "Planejamento")

      parent.parent = new_parent

      expect(parent).not_to be_valid
      expect(parent.errors[:parent]).to be_present
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

    it "rejects creating a child under a category that already has transactions" do
      create(:transaction, :expense, account: create(:account, user: user), category: parent)

      child = build(:category, user: user, parent: parent, name: "Aluguel")

      expect(child).not_to be_valid
      expect(child.errors[:parent]).to be_present
    end

    it "rejects transactions on categories that have children" do
      create(:category, user: user, parent: parent, name: "Aluguel")
      tx = build(:transaction, :expense, account: create(:account, user: user), category: parent)

      expect(tx).not_to be_valid
      expect(tx.errors[:category]).to be_present
    end
  end
end
