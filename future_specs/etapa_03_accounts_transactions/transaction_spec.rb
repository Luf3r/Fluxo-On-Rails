# spec/models/transaction_spec.rb
require "rails_helper"

RSpec.describe Transaction, type: :model do
  # ── Associations ─────────────────────────────────────────────────────────
  it { should belong_to(:account) }
  it { should belong_to(:category).optional }
  it { should belong_to(:transfer_pair).class_name("Transaction").optional }

  # ── Validations ──────────────────────────────────────────────────────────
  it { should validate_presence_of(:amount) }
  it { should validate_presence_of(:date) }
  it { should validate_presence_of(:transaction_type) }
  it { should validate_numericality_of(:amount).is_greater_than(0) }

  # ── Enums ────────────────────────────────────────────────────────────────
  describe "transaction_type enum" do
    it { should define_enum_for(:transaction_type)
      .with_values(income: "income", expense: "expense", transfer: "transfer") }
  end

  describe "status enum" do
    it { should define_enum_for(:status)
      .with_values(settled: "settled", pending: "pending") }
  end

  # ── Auto-pending for future dates ─────────────────────────────────────────
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

  # ── Scopes ────────────────────────────────────────────────────────────────
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

    describe ".by_category" do
      let(:cat_a) { create(:category) }
      let(:cat_b) { create(:category) }
      let!(:tx_a)  { create(:transaction, :expense, account: account, category: cat_a) }
      let!(:tx_b)  { create(:transaction, :expense, account: account, category: cat_b) }

      it "filters by category" do
        expect(Transaction.by_category(cat_a.id)).to include(tx_a)
        expect(Transaction.by_category(cat_a.id)).not_to include(tx_b)
      end
    end

    describe ".search" do
      let!(:tx) { create(:transaction, :income, account: account, description: "Salário mensal") }

      it "finds by partial case-insensitive description" do
        expect(Transaction.search("salário")).to include(tx)
        expect(Transaction.search("SALÁRIO")).to include(tx)
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
  end

  # ── Cache invalidation ───────────────────────────────────────────────────
  describe "analytics cache invalidation" do
    it "invalidates cache after create" do
      account = create(:account)
      expect(Rails.cache).to receive(:delete_matched).at_least(:once)
      create(:transaction, :income, account: account)
    end

    it "invalidates cache after update" do
      tx = create(:transaction, :income)
      expect(Rails.cache).to receive(:delete_matched).at_least(:once)
      tx.update!(amount: 999)
    end

    it "invalidates cache after destroy" do
      tx = create(:transaction, :income)
      expect(Rails.cache).to receive(:delete_matched).at_least(:once)
      tx.destroy!
    end
  end
end