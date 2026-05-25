# spec/requests/transactions_spec.rb
require "rails_helper"

RSpec.describe "Transactions", type: :request do
  let(:user)    { create(:user) }
  let(:other)   { create(:user) }
  let(:account) { create(:account, user: user) }

  before { sign_in user }

  describe "GET /transactions" do
    let!(:tx1) { create(:transaction, :income,  :settled, account: account, date: 1.day.ago) }
    let!(:tx2) { create(:transaction, :expense, :settled, account: account, date: Date.current) }
    let!(:tx3) { create(:transaction, :income,  account: create(:account, user: other)) }

    it "returns 200 and only current user's transactions" do
      get transactions_path
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(tx3.description.to_s)
    end

    context "filtering" do
      let(:cat) { create(:category, user: user) }
      let!(:cat_tx) do
        create(:transaction, :expense, :settled, account: account, category: cat,
               description: "Almoço", date: Date.current)
      end

      it "filters by category" do
        get transactions_path, params: { category_id: cat.id }
        expect(response.body).to include("Almoço")
      end

      it "filters by date range" do
        get transactions_path, params: {
          start_date: Date.current.to_s,
          end_date:   Date.current.to_s
        }
        expect(response.body).to include(tx2.description.to_s)
        expect(response.body).not_to include(tx1.description.to_s)
      end

      it "filters by search query" do
        create(:transaction, :income, :settled, account: account, description: "Freelance React")
        get transactions_path, params: { q: "freelance" }
        expect(response.body).to include("Freelance React")
        expect(response.body).not_to include(tx1.description.to_s)
      end

      it "filters by transaction_type" do
        get transactions_path, params: { transaction_type: "income" }
        expect(response.body).to include(tx1.description.to_s)
        expect(response.body).not_to include(tx2.description.to_s)
      end
    end

    context "pagination" do
      before { create_list(:transaction, 30, :income, :settled, account: account) }

      it "paginates results" do
        get transactions_path, params: { page: 1 }
        expect(response).to have_http_status(:ok)
        # Exact count depends on per_page setting, just check it doesn't blow up
      end
    end
  end

  describe "POST /transactions" do
    let(:category) { create(:category, user: user) }
    let(:valid_params) do
      { transaction: {
        description:      "Salário",
        amount:           5000.00,
        transaction_type: "income",
        date:             Date.current.to_s,
        account_id:       account.id,
        category_id:      category.id
      } }
    end

    it "creates a transaction" do
      expect { post transactions_path, params: valid_params }
        .to change(Transaction, :count).by(1)
    end

    it "associates with the current user's account" do
      post transactions_path, params: valid_params
      expect(Transaction.last.account.user).to eq(user)
    end

    it "rejects creating a transaction on another user's account" do
      other_account = create(:account, user: other)
      expect {
        post transactions_path, params: {
          transaction: valid_params[:transaction].merge(account_id: other_account.id)
        }
      }.not_to change(Transaction, :count)
    end

    it "sets future transaction as pending" do
      post transactions_path, params: {
        transaction: valid_params[:transaction].merge(date: 1.month.from_now.to_date.to_s)
      }
      expect(Transaction.last.status).to eq("pending")
    end

    context "with invalid params" do
      it "rejects zero amount" do
        expect {
          post transactions_path, params: {
            transaction: valid_params[:transaction].merge(amount: 0)
          }
        }.not_to change(Transaction, :count)
      end

      it "rejects missing date" do
        expect {
          post transactions_path, params: {
            transaction: valid_params[:transaction].merge(date: nil)
          }
        }.not_to change(Transaction, :count)
      end
    end
  end

  describe "PATCH /transactions/:id" do
    let(:tx) { create(:transaction, :expense, :settled, account: account, amount: 100.00) }

    it "updates the transaction" do
      patch transaction_path(tx), params: { transaction: { amount: 150.00 } }
      expect(tx.reload.amount).to eq(150.00)
    end

    it "rejects updating another user's transaction" do
      other_tx = create(:transaction, :expense, account: create(:account, user: other))
      patch transaction_path(other_tx), params: { transaction: { amount: 1.00 } }
      expect(other_tx.reload.amount).not_to eq(1.00)
    end
  end

  describe "DELETE /transactions/:id" do
    let!(:tx) { create(:transaction, :expense, account: account) }

    it "destroys the transaction" do
      expect { delete transaction_path(tx) }.to change(Transaction, :count).by(-1)
    end

    it "does not destroy another user's transaction" do
      other_tx = create(:transaction, :income, account: create(:account, user: other))
      expect { delete transaction_path(other_tx) rescue nil }
        .not_to change(Transaction, :count)
    end
  end

  describe "POST /transactions/import (Etapa 9)" do
    it "is a placeholder for CSV import spec — see spec/services/transactions/import_csv_spec.rb"
  end
end