# spec/models/transaction_spec.rb
require "rails_helper"

RSpec.describe Transaction, type: :model do
  it { should belong_to(:account) }
  it { should belong_to(:transfer_pair).class_name("Transaction").optional }
  it { should belong_to(:category).optional }
  it { should have_many(:transaction_tags).dependent(:destroy) }
  it { should have_many(:tags).through(:transaction_tags) }

  it { should validate_presence_of(:amount) }
  it { should validate_presence_of(:date) }
  it { should validate_presence_of(:transaction_type) }
  it { should validate_numericality_of(:amount).is_greater_than(0) }

  describe "transaction_type enum" do
    it { should define_enum_for(:transaction_type)
      .backed_by_column_of_type(:string)
      .with_values(income: "income", expense: "expense", transfer: "transfer") }
  end

  describe "status enum" do
    it { should define_enum_for(:status)
      .backed_by_column_of_type(:string)
      .with_values(settled: "settled", pending: "pending") }
  end

  describe "automatic status assignment" do
    context "when date is today" do
      it "defaults to settled" do
        t = create(:transaction, :income, date: Date.current)
        expect(t.status).to eq("settled")
      end
    end

    context "when date is in the past" do
      it "remains settled" do
        t = create(:transaction, :income, date: 1.week.ago.to_date)
        expect(t.status).to eq("settled")
      end
    end

    context "when date is in the future" do
      it "sets status to pending automatically" do
        t = create(:transaction, :income, date: 1.week.from_now.to_date, status: :settled)
        expect(t.status).to eq("pending")
      end

      it "overrides any explicit settled status for future date" do
        t = build(:transaction, :income, date: 1.month.from_now.to_date, status: :settled)
        t.save!
        expect(t.status).to eq("pending")
      end
    end
  end

  describe "amount limits" do
    it "rejects values outside the database decimal precision" do
      transaction = build(:transaction, amount: Transaction::MAX_AMOUNT + 0.01)

      expect(transaction).not_to be_valid
      expect(transaction.errors[:amount]).to be_present
    end
  end

  describe "category assignment" do
    let(:user) { create(:user) }
    let(:account) { create(:account, user: user) }

    it "accepts a compatible leaf category owned by the account user" do
      category = create(:category, user: user)
      transaction = build(:transaction, :expense, account: account, category: category)

      expect(transaction).to be_valid
    end

    it "rejects categories owned by another user" do
      category = create(:category, user: create(:user))
      transaction = build(:transaction, :expense, account: account, category: category)

      expect(transaction).not_to be_valid
      expect(transaction.errors[:category]).to be_present
    end

    it "rejects parent categories with children" do
      parent = create(:category, user: user)
      create(:category, user: user, parent: parent, name: "Aluguel")
      transaction = build(:transaction, :expense, account: account, category: parent)

      expect(transaction).not_to be_valid
      expect(transaction.errors[:category]).to be_present
    end

    it "rejects categories incompatible with the transaction type" do
      category = create(:category, user: user, category_type: "income")
      transaction = build(:transaction, :expense, account: account, category: category)

      expect(transaction).not_to be_valid
      expect(transaction.errors[:category]).to be_present
    end
  end

  describe "tag names" do
    let(:user) { create(:user) }
    let(:account) { create(:account, user: user) }

    it "creates and reuses user tags from comma-separated names" do
      create(:tag, user: user, name: "fixo")
      transaction = build(:transaction, :expense, account: account)

      expect {
        transaction.tag_names = "Fixo, Mensal"
        transaction.save!
      }.to change(Tag, :count).by(1)

      expect(transaction.tags.pluck(:name)).to contain_exactly("fixo", "mensal")
    end
  end

  describe "scopes" do
    let(:account) { create(:account) }

    describe ".by_period" do
      let!(:jan_tx)   { create(:transaction, :income, account: account, date: "2025-01-15") }
      let!(:feb_tx)   { create(:transaction, :income, account: account, date: "2025-02-10") }
      let!(:march_tx) { create(:transaction, :income, account: account, date: "2025-03-01") }

      it "returns transactions within the date range" do
        results = Transaction.by_period("2025-01-01", "2025-02-28")
        expect(results).to include(jan_tx, feb_tx)
        expect(results).not_to include(march_tx)
      end
    end

    describe ".search" do
      let!(:tx) { create(:transaction, :income, account: account, description: "Salario mensal") }

      it "finds by partial case-insensitive description" do
        expect(Transaction.search("salario")).to include(tx)
        expect(Transaction.search("SALARIO")).to include(tx)
        expect(Transaction.search("mensal")).to include(tx)
      end

      it "returns nothing for no match" do
        expect(Transaction.search("aluguel")).not_to include(tx)
      end
    end

    describe ".settled and .pending" do
      let!(:settled_tx) { create(:transaction, :income, :settled, account: account) }
      let!(:pending_tx) { create(:transaction, :income, :pending, account: account) }

      it { expect(Transaction.settled).to include(settled_tx) }
      it { expect(Transaction.settled).not_to include(pending_tx) }
      it { expect(Transaction.pending).to include(pending_tx) }
      it { expect(Transaction.pending).not_to include(settled_tx) }
    end

    describe ".current_month" do
      let!(:this_month) { create(:transaction, :expense, account: account, date: Date.current) }
      let!(:last_month) { create(:transaction, :expense, account: account, date: 1.month.ago) }

      it "returns only current month transactions" do
        expect(Transaction.current_month).to include(this_month)
        expect(Transaction.current_month).not_to include(last_month)
      end
    end

    describe "analytics filtering" do
      let!(:income_tx) { create(:transaction, :income, :settled, account: account, amount: 100.00) }
      let!(:transfer_tx) { create(:transaction, :transfer, :settled, account: account, amount: 999.00) }

      it "lets analytics exclude transfer rows from income and expense totals" do
        analytics_scope = Transaction.settled.where.not(transaction_type: :transfer)
        expect(analytics_scope).to include(income_tx)
        expect(analytics_scope).not_to include(transfer_tx)
      end
    end
  end
end
