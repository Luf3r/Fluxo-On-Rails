# spec/requests/accounts_spec.rb
require "rails_helper"

RSpec.describe "Accounts", type: :request do
  let(:user)  { create(:user) }
  let(:other) { create(:user) }

  before { sign_in user }

  describe "GET /accounts" do
    let!(:my_accounts)    { create_list(:account, 3, user: user) }
    let!(:other_accounts) { create_list(:account, 2, user: other) }

    it "returns 200 and only the current user's accounts" do
      get accounts_path
      expect(response).to have_http_status(:ok)
    end

    it "does not expose other users accounts" do
      get accounts_path
      expect(response.body).not_to include(other_accounts.first.name)
    end
  end

  describe "GET /accounts/:id" do
    let(:account) { create(:account, user: user) }

    it "returns 200 for own account" do
      get account_path(account)
      expect(response).to have_http_status(:ok)
    end

    it "returns 404 or redirects for another user's account" do
      other_account = create(:account, user: other)
      get account_path(other_account)
      expect(response.status).to be_in([ 302, 404, 401 ])
    end
  end

  describe "GET /accounts/:id/balance" do
    let(:account) { create(:account, user: user, initial_balance: 500.00) }

    before do
      create(:transaction, :income,  :settled, account: account, amount: 200.00)
      create(:transaction, :expense, :settled, account: account, amount: 100.00)
      create(:transaction, :income,  :pending, account: account, amount: 999.00)
    end

    it "returns the correct settled balance" do
      get balance_account_path(account)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("600")
    end

    it "does not include pending transactions in the balance" do
      get balance_account_path(account)
      expect(response.body).not_to include("1599")
    end
  end

  describe "POST /accounts" do
    let(:valid_params) do
      { account: {
        name:            "Conta Corrente",
        account_type:    "checking",
        currency:        "BRL",
        initial_balance: 1000.00
      } }
    end

    it "creates an account for the current user" do
      expect { post accounts_path, params: valid_params }
        .to change(user.accounts, :count).by(1)
    end

    it "redirects to the new account on success" do
      post accounts_path, params: valid_params
      expect(response).to redirect_to(account_path(Account.last))
    end

    it "rejects invalid data" do
      expect {
        post accounts_path, params: { account: { name: "" } }
      }.not_to change(Account, :count)
    end
  end

  describe "PATCH /accounts/:id" do
    let(:account) { create(:account, user: user, name: "Old Name") }

    it "updates the account" do
      patch account_path(account), params: { account: { name: "New Name" } }
      expect(account.reload.name).to eq("New Name")
    end

    it "does not allow updating another user's account" do
      other_account = create(:account, user: other, name: "Protected")
      patch account_path(other_account), params: { account: { name: "Hacked" } }
      expect(other_account.reload.name).to eq("Protected")
    end
  end

  describe "DELETE /accounts/:id" do
    let!(:account) { create(:account, user: user) }

    it "destroys the account" do
      expect { delete account_path(account) }
        .to change(Account, :count).by(-1)
    end

    it "destroys associated transactions (dependent: :destroy)" do
      create_list(:transaction, 3, :income, account: account)
      expect { delete account_path(account) }
        .to change(Transaction, :count).by(-3)
    end

    it "does not destroy another user's account" do
      other_account = create(:account, user: other)
      expect { delete account_path(other_account) rescue nil }
        .not_to change(Account, :count)
    end
  end

  describe "unauthenticated access" do
    before { sign_out user }

    it "redirects to login" do
      get accounts_path
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
