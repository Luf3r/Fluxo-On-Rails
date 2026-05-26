# spec/requests/goals_spec.rb
require "rails_helper"

RSpec.describe "Goals", type: :request do
  let(:user)    { create(:user) }
  let(:account) { create(:account, user: user, initial_balance: 100.00) }

  before { sign_in user }

  describe "GET /goals" do
    let!(:my_goals) { create_list(:goal, 2, user: user, account: account) }
    let!(:other_goal) { create(:goal, user: create(:user), account: create(:account)) }

    it "returns 200" do
      get goals_path
      expect(response).to have_http_status(:ok)
    end

    it "does not expose other users goals" do
      get goals_path
      expect(response.body).not_to include(other_goal.name)
    end
  end

  describe "GET /goals/:id/progress" do
    let(:goal) { create(:goal, user: user, account: account, target_amount: 500.00) }

    it "returns 200 with progress data" do
      get progress_goal_path(goal)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("percent")
      expect(response.body).to include("500")
    end

    it "denies access to another user's goal" do
      other = create(:goal, user: create(:user), account: create(:account))
      get progress_goal_path(other)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /goals/:id/projection" do
    let(:goal) { create(:goal, user: user, account: account, target_amount: 5000.00) }

    it "returns 200" do
      get projection_goal_path(goal)
      expect(response).to have_http_status(:ok)
    end

    it "returns projection null message when no history" do
      get projection_goal_path(goal)
      expect(response.body).to include("projection")
      expect(response.body).to include("null")
    end

    it "denies access to another user's goal" do
      other = create(:goal, user: create(:user), account: create(:account))
      get projection_goal_path(other)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /goals" do
    let(:valid_params) do
      { goal: {
        name:          "Fundo de emergência",
        target_amount: 10_000.00,
        deadline:      6.months.from_now.to_date.to_s,
        account_id:    account.id
      } }
    end

    it "creates a goal" do
      expect { post goals_path, params: valid_params }
        .to change(Goal, :count).by(1)
    end

    it "rejects a past deadline" do
      expect {
        post goals_path, params: {
          goal: valid_params[:goal].merge(deadline: 1.day.ago.to_date.to_s)
        }
      }.not_to change(Goal, :count)
    end

    it "rejects target_amount of zero" do
      expect {
        post goals_path, params: {
          goal: valid_params[:goal].merge(target_amount: 0)
        }
      }.not_to change(Goal, :count)
    end

    it "rejects a goal attached to another user's account" do
      other_account = create(:account, user: create(:user))

      expect {
        post goals_path, params: {
          goal: valid_params[:goal].merge(account_id: other_account.id)
        }
      }.not_to change(Goal, :count)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /goals/:id" do
    let!(:goal) { create(:goal, user: user, account: account) }

    it "destroys the goal" do
      expect { delete goal_path(goal) }.to change(Goal, :count).by(-1)
    end

    it "does not destroy another user's goal" do
      other = create(:goal, user: create(:user), account: create(:account))

      expect { delete goal_path(other) }.not_to change(Goal, :count)
      expect(response).to have_http_status(:not_found)
    end
  end
end
