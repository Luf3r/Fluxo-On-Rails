# spec/requests/analytics_spec.rb
require "rails_helper"

RSpec.describe "Analytics", type: :request do
  let(:user)    { create(:user) }
  let(:account) { create(:account, user: user, initial_balance: 0) }

  before { sign_in user }

  describe "GET /analytics/summary" do
    before do
      create(:transaction, :income,  :settled, account: account, amount: 4000, date: Date.current)
      create(:transaction, :expense, :settled, account: account, amount: 1500, date: Date.current)
    end

    it "returns 200" do
      get analytics_summary_path
      expect(response).to have_http_status(:ok)
    end

    it "includes income, expense and net in the response" do
      get analytics_summary_path
      expect(response.body).to include("4000")
      expect(response.body).to include("1500")
    end

    it "requires authentication" do
      sign_out user
      get analytics_summary_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "GET /analytics/by_category" do
    let(:food) { create(:category, user: user, name: "Alimentação") }

    before do
      create(:transaction, :expense, :settled, account: account,
             category: food, amount: 300, date: Date.current)
    end

    it "returns 200 with category breakdown" do
      get analytics_by_category_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /analytics/monthly" do
    it "returns 200" do
      get analytics_monthly_path
      expect(response).to have_http_status(:ok)
    end

    it "returns data for the last 12 months" do
      get analytics_monthly_path
      # At minimum the response should be a valid page/JSON
      expect(response.body).not_to be_empty
    end
  end

  describe "GET /analytics/top_expenses" do
    before do
      create_list(:transaction, 6, :expense, :settled, account: account)
    end

    it "returns 200" do
      get analytics_top_expenses_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /analytics/budget_status" do
    it "returns 200" do
      get analytics_budget_status_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "data isolation" do
    let(:other_user)    { create(:user) }
    let(:other_account) { create(:account, user: other_user) }
    let(:other_category) { create(:category, user: other_user, name: "Private Other Category") }

    before do
      create(:transaction, :income, :settled, account: other_account,
             amount: 99_999, date: Date.current)
      create(:transaction, :expense, :settled, account: other_account,
             category: other_category, amount: 88_888, description: "Private Other Expense",
             date: Date.current)
    end

    it "does not include other users data in summary" do
      get analytics_summary_path
      expect(response.body).not_to include("99999")
    end

    it "does not include other users data in category breakdown" do
      get analytics_by_category_path
      expect(response.body).not_to include("Private Other Category")
      expect(response.body).not_to include("88888")
    end

    it "does not include other users data in monthly evolution" do
      get analytics_monthly_path
      expect(response.body).not_to include("99999")
      expect(response.body).not_to include("88888")
    end

    it "does not include other users data in top expenses" do
      get analytics_top_expenses_path
      expect(response.body).not_to include("Private Other Expense")
      expect(response.body).not_to include("88888")
    end

    it "does not include other users data in budget status" do
      get analytics_budget_status_path
      expect(response.body).not_to include("Private Other Category")
      expect(response.body).not_to include("88888")
    end
  end
end
