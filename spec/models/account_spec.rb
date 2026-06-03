# spec/models/account_spec.rb
require "rails_helper"

RSpec.describe Account, type: :model do
  it { should belong_to(:user) }
  it { should have_many(:transactions).dependent(:destroy) }

  it { should validate_presence_of(:name) }
  it { should validate_numericality_of(:initial_balance).is_greater_than_or_equal_to(0) }
  it { should validate_inclusion_of(:account_type)
    .in_array(%w[checking savings investment cash]) }

  describe "defaults" do
    it "sets initial_balance to 0 if not provided" do
      account = build(:account, initial_balance: nil)
      account.valid?

      expect(account.initial_balance).to eq(0)
      expect(account.errors[:initial_balance]).to be_empty
    end
  end

  describe "initial balance limits" do
    it "rejects values outside the database decimal precision" do
      account = build(:account, initial_balance: Account::MAX_INITIAL_BALANCE + 0.01)

      expect(account).not_to be_valid
      expect(account.errors[:initial_balance]).to be_present
    end
  end

  describe "ownership scoping" do
    let(:user_a) { create(:user) }
    let(:user_b) { create(:user) }
    let!(:account_a) { create(:account, user: user_a) }
    let!(:account_b) { create(:account, user: user_b) }

    it "scopes accounts to owner" do
      expect(user_a.accounts).to include(account_a)
      expect(user_a.accounts).not_to include(account_b)
    end
  end

  describe "#current_balance" do
    let(:account) { create(:account, initial_balance: 1000.00) }

    it "equals initial_balance when no transactions" do
      expect(account.current_balance).to eq(1000.00)
    end

    it "adds settled income to initial balance" do
      create(:transaction, :income, :settled, account: account, amount: 500.00)
      expect(account.current_balance).to eq(1500.00)
    end

    it "subtracts settled expenses from initial balance" do
      create(:transaction, :expense, :settled, account: account, amount: 200.00)
      expect(account.current_balance).to eq(800.00)
    end

    it "ignores pending transactions" do
      create(:transaction, :income, :pending, account: account, amount: 300.00)
      expect(account.current_balance).to eq(1000.00)
    end

    it "combines income and expenses correctly" do
      create(:transaction, :income,  :settled, account: account, amount: 500.00)
      create(:transaction, :expense, :settled, account: account, amount: 300.00)
      create(:transaction, :income,  :pending, account: account, amount: 100.00)
      expect(account.current_balance).to eq(1200.00)
    end

    it "handles multiple transactions of each type" do
      create_list(:transaction, 3, :income,  :settled, account: account, amount: 100.00)
      create_list(:transaction, 2, :expense, :settled, account: account, amount: 50.00)
      expect(account.current_balance).to eq(1200.00)
    end

    it "subtracts outgoing transfers and adds incoming transfers to account balances" do
      other = create(:account, user: account.user, initial_balance: 0)
      Transfers::Create.new.call(
        from_account: account,
        to_account: other,
        amount: 200.00,
        date: Date.current,
        description: "Poupanca"
      )

      expect(account.current_balance).to eq(800.00)
      expect(other.current_balance).to eq(200.00)
    end
  end

  describe "account_type enum" do
    it "defines checking, savings, investment, cash" do
      expect(Account.account_types.keys)
        .to match_array(%w[checking savings investment cash])
    end
  end
end
