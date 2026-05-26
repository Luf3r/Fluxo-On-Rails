# spec/models/goal_spec.rb
require "rails_helper"

RSpec.describe Goal, type: :model do
  it { should belong_to(:user) }
  it { should belong_to(:account) }

  it { should validate_presence_of(:name) }
  it { should validate_presence_of(:target_amount) }
  it { should validate_numericality_of(:target_amount).is_greater_than(0) }

  describe "deadline validation" do
    it "rejects a deadline in the past" do
      goal = build(:goal, deadline: 1.day.ago.to_date)
      expect(goal).not_to be_valid
      expect(goal.errors[:deadline]).to be_present
    end

    it "accepts a deadline in the future" do
      goal = build(:goal, deadline: 1.year.from_now.to_date)
      expect(goal).to be_valid
    end

    it "accepts no deadline (optional)" do
      goal = build(:goal, deadline: nil)
      expect(goal).to be_valid
    end
  end

  describe "#progress" do
    let(:account) { create(:account, initial_balance: 500.00) }
    let(:goal)    { create(:goal, account: account, target_amount: 1000.00) }

    before do
      create(:transaction, :income, :settled,
             account: account, amount: 200.00, date: Date.current)
    end

    it "returns current balance" do
      expect(goal.progress[:current]).to eq(700.00)
    end

    it "returns target amount" do
      expect(goal.progress[:target]).to eq(1000.00)
    end

    it "returns percentage as a float" do
      expect(goal.progress[:percent]).to eq(70.0)
    end

    it "caps percent at 100 when goal is exceeded" do
      create(:transaction, :income, :settled, account: account, amount: 1000.00)
      expect(goal.progress[:percent]).to be >= 100.0
    end
  end

  describe "#projection" do
    let(:account) { create(:account, initial_balance: 0.00) }
    let(:goal)    { create(:goal, account: account, target_amount: 6000.00) }

    context "with at least 1 month of history" do
      before do
        3.times do |i|
          create(:transaction, :income, :settled,
                 account: account, amount: 1000.00,
                 date: i.months.ago.to_date)
        end
      end

      it "returns months_remaining as a positive integer" do
        result = goal.projection
        expect(result[:months_remaining]).to be_a(Integer)
        expect(result[:months_remaining]).to be > 0
      end

      it "returns an estimated completion date" do
        result = goal.projection
        expect(result[:estimated_date]).to be_a(Date)
        expect(result[:estimated_date]).to be > Date.current
      end

      it "estimates correctly based on average monthly income" do
        # avg = 1000/month, remaining = 6000 - 3000 (from 3 x 1000)
        result = goal.projection
        expect(result[:months_remaining]).to eq(3)
      end
    end

    context "with insufficient history (less than 1 month)" do
      it "returns nil for projection fields" do
        result = goal.projection
        expect(result[:months_remaining]).to be_nil
        expect(result[:estimated_date]).to be_nil
      end
    end

    context "when average contribution is zero or negative" do
      before do
        create(:transaction, :expense, :settled,
               account: account, amount: 100, date: 2.months.ago)
      end

      it "returns nil projection" do
        result = goal.projection
        expect(result[:months_remaining]).to be_nil
      end
    end
  end
end
