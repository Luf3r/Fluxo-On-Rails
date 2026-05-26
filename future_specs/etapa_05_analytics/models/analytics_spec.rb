# spec/models/analytics_spec.rb
require "rails_helper"

RSpec.describe Analytics, type: :model do
  # Analytics is a plain Ruby module/class — no AR table.
  # If implemented as a module on Transaction, adjust the describe target.

  let(:user)    { create(:user) }
  let(:account) { create(:account, user: user, initial_balance: 0) }
  let(:other_user) { create(:user) }
  let(:other_account) { create(:account, user: other_user, initial_balance: 0) }

  def create_tx(type:, amount:, date: Date.current, status: :settled, category: nil)
    create(:transaction, transaction_type: type, amount: amount, date: date,
           status: status, account: account, category: category)
  end

  def create_other_tx(type:, amount:, date: Date.current, status: :settled, category: nil, description: nil)
    create(:transaction, transaction_type: type, amount: amount, date: date,
           status: status, account: other_account, category: category, description: description)
  end

  describe ".monthly_summary" do
    before do
      create_tx(type: :income,  amount: 5000, date: Date.current)
      create_tx(type: :income,  amount: 1000, date: Date.current)
      create_tx(type: :expense, amount: 2000, date: Date.current)
      create_tx(type: :expense, amount: 500,  date: Date.current)
      create_tx(type: :income,  amount: 9999, date: 2.months.ago, status: :settled) # outside period
    end

    it "returns total income for current month" do
      summary = Analytics.monthly_summary(user)
      expect(summary[:income]).to eq(6000)
    end

    it "returns total expense for current month" do
      summary = Analytics.monthly_summary(user)
      expect(summary[:expense]).to eq(2500)
    end

    it "returns net balance (income - expense)" do
      summary = Analytics.monthly_summary(user)
      expect(summary[:net]).to eq(3500)
    end

    it "excludes pending transactions" do
      create_tx(type: :income, amount: 999, date: Date.current, status: :pending)
      summary = Analytics.monthly_summary(user)
      expect(summary[:income]).to eq(6000)
    end

    it "respects a custom period" do
      period = 2.months.ago.all_month
      summary = Analytics.monthly_summary(user, period)
      expect(summary[:income]).to eq(9999)
    end

    it "excludes another user's transactions" do
      create_other_tx(type: :income, amount: 99_999, date: Date.current)
      create_other_tx(type: :expense, amount: 88_888, date: Date.current)

      summary = Analytics.monthly_summary(user)
      expect(summary[:income]).to eq(6000)
      expect(summary[:expense]).to eq(2500)
    end
  end

  describe ".by_category" do
    let(:food)      { create(:category, user: user, name: "Alimentação") }
    let(:transport) { create(:category, user: user, name: "Transporte") }
    let(:other_category) { create(:category, user: other_user, name: "Private Other Category") }

    before do
      create_tx(type: :expense, amount: 500, category: food)
      create_tx(type: :expense, amount: 300, category: food)
      create_tx(type: :expense, amount: 200, category: transport)
    end

    it "groups expenses by category" do
      result = Analytics.by_category(user)
      expect(result.find { |r| r[:name] == "Alimentação" }[:total]).to eq(800)
      expect(result.find { |r| r[:name] == "Transporte" }[:total]).to eq(200)
    end

    it "includes percentage of total for each category" do
      result = Analytics.by_category(user)
      food_row = result.find { |r| r[:name] == "Alimentação" }
      expect(food_row[:percent]).to eq(80.0)
    end

    it "orders by total descending" do
      result = Analytics.by_category(user)
      totals = result.map { |r| r[:total] }
      expect(totals).to eq(totals.sort.reverse)
    end

    it "excludes another user's categories and transactions" do
      create_other_tx(type: :expense, amount: 99_999, category: other_category)

      result = Analytics.by_category(user)
      expect(result.map { |r| r[:name] }).not_to include("Private Other Category")
      expect(result.map { |r| r[:total] }).not_to include(99_999)
    end
  end

  describe ".monthly_evolution" do
    before do
      (1..6).each do |i|
        date = i.months.ago.to_date
        create_tx(type: :income,  amount: 3000, date: date)
        create_tx(type: :expense, amount: 1500, date: date)
      end
    end

    it "returns data for the last 12 months" do
      result = Analytics.monthly_evolution(user)
      expect(result.length).to be >= 6
    end

    it "includes income, expense and net for each month" do
      result = Analytics.monthly_evolution(user)
      month  = result.first
      expect(month).to have_key(:month)
      expect(month).to have_key(:income)
      expect(month).to have_key(:expense)
      expect(month).to have_key(:net)
    end

    it "calculates net correctly per month" do
      result = Analytics.monthly_evolution(user)
      result.each do |m|
        expect(m[:net]).to eq(m[:income] - m[:expense])
      end
    end

    it "excludes another user's monthly totals" do
      create_other_tx(type: :income, amount: 99_999, date: Date.current)

      result = Analytics.monthly_evolution(user)
      expect(result.map { |m| m[:income] }).not_to include(99_999)
    end
  end

  describe ".top_expenses" do
    before do
      create_tx(type: :expense, amount: 100)
      create_tx(type: :expense, amount: 500)
      create_tx(type: :expense, amount: 250)
      create_tx(type: :expense, amount: 750)
      create_tx(type: :expense, amount: 50)
      create_tx(type: :expense, amount: 999)  # top
    end

    it "returns the 5 highest expenses" do
      result = Analytics.top_expenses(user)
      expect(result.length).to eq(5)
      expect(result.first[:amount]).to eq(999)
    end

    it "orders by amount descending" do
      result = Analytics.top_expenses(user)
      amounts = result.map { |r| r[:amount] }
      expect(amounts).to eq(amounts.sort.reverse)
    end

    it "excludes another user's expenses" do
      create_other_tx(type: :expense, amount: 99_999, description: "Private Other Expense")

      result = Analytics.top_expenses(user)
      expect(result.map { |r| r[:amount] }).not_to include(99_999)
      expect(result.map { |r| r[:description] }).not_to include("Private Other Expense")
    end
  end

  describe "caching" do
    it "caches the summary result" do
      allow(Rails.cache).to receive(:fetch).and_call_original
      2.times { Analytics.monthly_summary(user) }
      expect(Rails.cache).to have_received(:fetch).once
    end

    it "cache expires after 5 minutes" do
      period = Date.current.all_month
      summary_key = "analytics/summary/#{user.id}/#{period.begin.to_date}/#{period.end.to_date}"
      Rails.cache.write(summary_key, "stale", expires_in: 5.minutes)
      travel 6.minutes do
        expect(Rails.cache.read(summary_key)).to be_nil
      end
    end

    it "uses separate cache entries for different summary periods" do
      current_period = Date.current.all_month
      previous_period = 1.month.ago.all_month

      expect(Rails.cache).to receive(:fetch)
        .with("analytics/summary/#{user.id}/#{current_period.begin.to_date}/#{current_period.end.to_date}", expires_in: 5.minutes)
        .and_call_original
      expect(Rails.cache).to receive(:fetch)
        .with("analytics/summary/#{user.id}/#{previous_period.begin.to_date}/#{previous_period.end.to_date}", expires_in: 5.minutes)
        .and_call_original

      Analytics.monthly_summary(user, current_period)
      Analytics.monthly_summary(user, previous_period)
    end
  end
end
