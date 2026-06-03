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

    it "renders the Portuguese accounts page without missing translations" do
      get accounts_path(locale: :"pt-BR")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Contas")
      expect(response.body).to include("Configuracoes")
      expect(response.body).not_to include("translation missing")
      expect(response.body).not_to include("Translation missing")
    end

    it "renders negative balances with a red treatment" do
      negative_account = my_accounts.first
      create(:transaction, :expense, :settled, account: negative_account, amount: 250.00)

      get accounts_path

      expect(response.body).to include("text-red-700")
      expect(response.body).to include(negative_account.name)
    end
  end

  describe "GET /accounts/:id" do
    let(:account) { create(:account, user: user) }

    it "returns 200 for own account" do
      get account_path(account)
      expect(response).to have_http_status(:ok)
    end

    it "returns 404 for another user's account" do
      other_account = create(:account, user: other)
      get account_path(other_account)
      expect(response).to have_http_status(:not_found)
    end

    it "renders a negative balance in red" do
      create(:transaction, :expense, :settled, account: account, amount: 250.00)

      get account_path(account)

      expect(response.body).to include("text-red-700")
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

    it "formats the balance according to the current locale" do
      get balance_account_path(account, locale: :"pt-BR")
      expect(response.body).to include("R$ 600,00")
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

    it "rejects huge initial balances without raising a server error" do
      expect {
        post accounts_path(locale: :"pt-BR"), params: {
          account: valid_params[:account].merge(initial_balance: "999999999999999999999999")
        }
      }.not_to change(Account, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("valor menor")
      expect(response.body).not_to include("RangeError")
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
      expect(response).to have_http_status(:not_found)
    end

    it "rejects huge initial balances without changing the account" do
      patch account_path(account, locale: :"pt-BR"), params: {
        account: { initial_balance: "999999999999999999999999" }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(account.reload.initial_balance).to eq(100.00)
      expect(response.body).to include("valor menor")
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

    it "destroys paired transfer rows in other accounts to preserve transfer invariants" do
      other_account = create(:account, user: user)
      Transfers::Create.new.call(
        from_account: account,
        to_account: other_account,
        amount: 10.00,
        date: Date.current,
        description: "Poupanca"
      )

      expect { delete account_path(account) }
        .to change(Transaction, :count).by(-2)
      expect(other_account.reload.transactions).to be_empty
    end

    it "does not destroy another user's account" do
      other_account = create(:account, user: other)
      expect { delete account_path(other_account) }
        .not_to change(Account, :count)
      expect(response).to have_http_status(:not_found)
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
