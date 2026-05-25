# spec/models/recurring_rule_spec.rb
require "rails_helper"

RSpec.describe RecurringRule, type: :model do
  it { should belong_to(:transaction) }

  it { should validate_presence_of(:frequency) }
  it { should validate_presence_of(:next_date) }
  it { should validate_inclusion_of(:frequency)
    .in_array(%w[daily weekly monthly yearly]) }

  describe "defaults" do
    it "is active by default" do
      rule = build(:recurring_rule)
      expect(rule.active).to be(true)
    end
  end

  describe "#advance_next_date!" do
    context "monthly frequency" do
      let(:rule) { create(:recurring_rule, frequency: "monthly", next_date: Date.new(2025, 1, 15)) }

      it "advances next_date by one month" do
        rule.advance_next_date!
        expect(rule.reload.next_date).to eq(Date.new(2025, 2, 15))
      end
    end

    context "weekly frequency" do
      let(:rule) { create(:recurring_rule, frequency: "weekly", next_date: Date.new(2025, 1, 6)) }

      it "advances next_date by one week" do
        rule.advance_next_date!
        expect(rule.reload.next_date).to eq(Date.new(2025, 1, 13))
      end
    end

    context "yearly frequency" do
      let(:rule) { create(:recurring_rule, frequency: "yearly", next_date: Date.new(2025, 3, 10)) }

      it "advances next_date by one year" do
        rule.advance_next_date!
        expect(rule.reload.next_date).to eq(Date.new(2026, 3, 10))
      end
    end

    context "daily frequency" do
      let(:rule) { create(:recurring_rule, frequency: "daily", next_date: Date.new(2025, 1, 1)) }

      it "advances next_date by one day" do
        rule.advance_next_date!
        expect(rule.reload.next_date).to eq(Date.new(2025, 1, 2))
      end
    end

    context "end conditions" do
      it "marks rule as inactive when end_date is reached" do
        rule = create(:recurring_rule, frequency: "monthly",
                      next_date: Date.new(2025, 3, 1),
                      end_date:  Date.new(2025, 3, 1))
        rule.advance_next_date!
        expect(rule.reload.active).to be(false)
      end

      it "marks rule as inactive when max_occurrences is reached" do
        rule = create(:recurring_rule, frequency: "monthly",
                      next_date:          Date.new(2025, 1, 1),
                      max_occurrences:    3,
                      occurrences_count:  2)
        rule.advance_next_date!
        expect(rule.reload.active).to be(false)
      end

      it "increments occurrences_count after each advance" do
        rule = create(:recurring_rule, frequency: "monthly",
                      next_date: Date.current, occurrences_count: 0)
        rule.advance_next_date!
        expect(rule.reload.occurrences_count).to eq(1)
      end
    end
  end

  describe "scopes" do
    let!(:active_due)     { create(:recurring_rule, active: true,  next_date: Date.current) }
    let!(:active_future)  { create(:recurring_rule, active: true,  next_date: 1.week.from_now) }
    let!(:inactive_due)   { create(:recurring_rule, active: false, next_date: Date.current) }

    it "returns active rules due today or earlier" do
      due = RecurringRule.active.where("next_date <= ?", Date.current)
      expect(due).to include(active_due)
      expect(due).not_to include(active_future, inactive_due)
    end
  end
end
