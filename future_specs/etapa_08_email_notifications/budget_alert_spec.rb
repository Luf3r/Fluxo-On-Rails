# spec/models/budget_alert_spec.rb
require "rails_helper"

RSpec.describe "Budget alert on transaction", type: :model do
  let(:user)     { create(:user) }
  let(:account)  { create(:account, user: user) }
  let(:category) { create(:category, user: user, budget: 1000.00) }

  def create_expense(amount)
    create(:transaction, :expense, :settled,
           account: account, category: category,
           amount: amount, date: Date.current)
  end

  describe "80% threshold" do
    it "enqueues a budget alert when expense reaches 80%" do
      create_expense(700.00)  # 70% — no alert
      expect(BudgetMailer).not_to have_received(:alert)

      expect {
        create_expense(100.00)  # now 80% — trigger
      }.to have_enqueued_mail(BudgetMailer, :alert)
    end
  end

  describe "100% threshold" do
    it "enqueues a budget alert when budget is exceeded" do
      expect {
        create_expense(1050.00)  # 105%
      }.to have_enqueued_mail(BudgetMailer, :alert)
    end
  end

  describe "below threshold" do
    it "does not enqueue an alert when below 80%" do
      expect {
        create_expense(750.00)  # 75%
      }.not_to have_enqueued_mail(BudgetMailer, :alert)
    end
  end

  describe "deduplication" do
    it "does not send the same alert twice in the same month" do
      create_expense(850.00)   # first time hits 85%
      expect { create_expense(10.00) }  # second time still above 80%
        .not_to have_enqueued_mail(BudgetMailer, :alert)
    end
  end

  describe "without budget set" do
    let(:category_no_budget) { create(:category, user: user, budget: nil) }

    it "does not raise and does not enqueue alert" do
      expect {
        create(:transaction, :expense, :settled,
               account: account, category: category_no_budget, amount: 999)
      }.not_to have_enqueued_mail(BudgetMailer, :alert)
    end
  end

  describe "pending transaction" do
    it "does not trigger alert for pending transactions" do
      expect {
        create(:transaction, :expense, :pending,
               account: account, category: category, amount: 900)
      }.not_to have_enqueued_mail(BudgetMailer, :alert)
    end
  end
end
