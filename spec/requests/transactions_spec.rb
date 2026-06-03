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

    it "renders the Portuguese transaction page without missing translations" do
      get transactions_path(locale: :"pt-BR")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Transacoes")
      expect(response.body).to include("Configuracoes")
      expect(response.body).not_to include("translation missing")
      expect(response.body).not_to include("Translation missing")
    end

    it "localizes system category names without changing custom category names" do
      system_category = create(:category, :system, name: "Mercado", category_type: "expense")
      custom_category = create(:category, :income, user: user, name: "Mercado pessoal")
      tx2.update!(category: system_category)
      tx1.update!(category: custom_category)

      get transactions_path(locale: :en)

      expect(response.body).to include("Groceries")
      expect(response.body).to include(custom_category.name)
    end

    it "keeps the current locale when the filter form is submitted" do
      get transactions_path(locale: :"pt-BR")

      expect(response.body).to include('name="locale"')
      expect(response.body).to include('value="pt-BR"')
    end

    it "labels date filters with clear start and end meaning" do
      get transactions_path(locale: :"pt-BR")

      expect(response.body).to include("Data inicial")
      expect(response.body).to include("Data final")
    end

    context "filtering" do
      it "filters by date range" do
        get transactions_path, params: {
          start_date: Date.current.to_s,
          end_date:   Date.current.to_s
        }
        expect(response.body).to include(tx2.description.to_s)
        expect(response.body).not_to include(tx1.description.to_s)
      end

      it "ignores invalid date filters instead of raising a server error" do
        get transactions_path(locale: :"pt-BR"), params: {
          start_date: "nao-e-data",
          end_date: Date.current.to_s
        }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Transacoes")
        expect(response.body).not_to include("Date::Error")
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

      it "filters by category" do
        groceries = create(:category, :income, user: user, name: "Groceries")
        rent = create(:category, user: user, name: "Rent")
        tx1.update!(category: groceries)
        tx2.update!(category: rent)

        get transactions_path, params: { category_id: groceries.id }

        expect(response.body).to include(tx1.description.to_s)
        expect(response.body).not_to include(tx2.description.to_s)
      end

      it "filters by tag" do
        recurring = create(:tag, user: user, name: "recorrente")
        occasional = create(:tag, user: user, name: "eventual")
        tx1.tags << recurring
        tx2.tags << occasional

        get transactions_path, params: { tag_id: recurring.id }

        expect(response.body).to include(tx1.description.to_s)
        expect(response.body).not_to include(tx2.description.to_s)
      end

      it "does not apply another user's category as a valid filter" do
        other_category = create(:category, user: other, name: "Private")

        get transactions_path, params: { category_id: other_category.id }

        expect(response.body).not_to include(tx1.description.to_s)
        expect(response.body).not_to include(tx2.description.to_s)
      end
    end

    context "pagination" do
      before do
        30.times do |index|
          create(:transaction, :income, :settled,
                 account: account,
                 description: "Paginated income #{index + 1}")
        end
      end

      it "uses Pagy with 25 transactions per page by default" do
        get transactions_path, params: { page: 1, q: "Paginated income" }
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Showing 1-25 of 30")
        expect(response.body).to include("Paginated income 30")
        expect(response.body).not_to include("Paginated income 5")
      end
    end
  end

  describe "GET /transactions/new" do
    before { account }

    it "uses a clear localized destination prompt instead of ambiguous copy" do
      get new_transaction_path(locale: :"pt-BR")

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Selecione a conta de destino")
      expect(response.body).not_to include("Apenas para transferencias")
      expect(response.body).not_to include("translation missing")
    end
  end

  describe "GET /transactions/:id/edit" do
    it "does not offer transfer conversion for a regular transaction" do
      tx = create(:transaction, :expense, :settled, account: account)

      get edit_transaction_path(tx, locale: :"pt-BR")

      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include('value="transfer"')
    end
  end

  describe "POST /transactions" do
    let(:valid_params) do
      { transaction: {
        description:      "Salario",
        amount:           5000.00,
        transaction_type: "income",
        date:             Date.current.to_s,
        account_id:       account.id
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

    it "assigns a current user's category and tags" do
      category = create(:category, :income, user: user, name: "Freela")

      post transactions_path, params: {
        transaction: valid_params[:transaction].merge(
          category_id: category.id,
          tag_names: "cliente, imposto"
        )
      }

      transaction = Transaction.order(:created_at).last
      expect(transaction.category).to eq(category)
      expect(transaction.tags.pluck(:name)).to contain_exactly("cliente", "imposto")
      expect(transaction.tags.pluck(:user_id).uniq).to eq([ user.id ])
    end

    it "rejects another user's category" do
      category = create(:category, user: other)

      expect {
        post transactions_path, params: {
          transaction: valid_params[:transaction].merge(category_id: category.id)
        }
      }.not_to change(Transaction, :count)

      expect(response).to have_http_status(:not_found)
    end

    it "rejects creating a transaction on another user's account" do
      other_account = create(:account, user: other)
      expect {
        post transactions_path, params: {
          transaction: valid_params[:transaction].merge(account_id: other_account.id)
        }
      }.not_to change(Transaction, :count)
      expect(response).to have_http_status(:not_found)
    end

    it "sets future transaction as pending" do
      post transactions_path, params: {
        transaction: valid_params[:transaction].merge(date: 1.month.from_now.to_date.to_s)
      }
      expect(Transaction.last.status).to eq("pending")
    end

    it "redirects back to the localized list and shows the created transaction" do
      post transactions_path(locale: :"pt-BR"), params: {
        transaction: valid_params[:transaction].merge(description: "Bonus local")
      }

      expect(response).to redirect_to(transactions_path(locale: :"pt-BR"))

      follow_redirect!
      expect(response.body).to include("Bonus local")
      expect(response.body).to include("Transacoes")
      expect(response.body).not_to include("translation missing")
    end

    it "shows a newly-created transaction on the first page when the list is full" do
      25.times do |index|
        create(:transaction, :income, :settled,
               account: account,
               date: Date.current,
               description: "Existing current day #{index + 1}")
      end

      post transactions_path(locale: :"pt-BR"), params: {
        transaction: valid_params[:transaction].merge(description: "Bonus topo")
      }

      follow_redirect!

      expect(response.body).to include("Bonus topo")
    end

    it "rejects huge amounts without raising a server error" do
      expect {
        post transactions_path(locale: :"pt-BR"), params: {
          transaction: valid_params[:transaction].merge(amount: "999999999999999999999999")
        }
      }.not_to change(Transaction, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("valor menor")
      expect(response.body).not_to include("RangeError")
    end

    it "rejects transfers to the same account with a user-facing error" do
      expect {
        post transactions_path(locale: :"pt-BR"), params: {
          transaction: valid_params[:transaction].merge(
            transaction_type: "transfer",
            to_account_id: account.id
          )
        }
      }.not_to change(Transaction, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("conta de destino diferente")
    end

    it "requires a destination account for transfers" do
      expect {
        post transactions_path(locale: :"pt-BR"), params: {
          transaction: valid_params[:transaction].merge(
            transaction_type: "transfer",
            to_account_id: ""
          )
        }
      }.not_to change(Transaction, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Informe a conta de destino")
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

    it "updates category and tags" do
      category = create(:category, user: user, name: "Casa")

      patch transaction_path(tx), params: {
        transaction: {
          amount: "150.00",
          category_id: category.id,
          tag_names: "fixo, mensal"
        }
      }

      expect(tx.reload.category).to eq(category)
      expect(tx.tags.pluck(:name)).to contain_exactly("fixo", "mensal")
    end

    it "rejects updating another user's transaction" do
      other_tx = create(:transaction, :expense, account: create(:account, user: other))
      patch transaction_path(other_tx), params: { transaction: { amount: 1.00 } }
      expect(other_tx.reload.amount).not_to eq(1.00)
      expect(response).to have_http_status(:not_found)
    end

    it "rejects huge amounts without changing the transaction" do
      patch transaction_path(tx, locale: :"pt-BR"), params: {
        transaction: { amount: "999999999999999999999999" }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(tx.reload.amount).to eq(100.00)
      expect(response.body).to include("valor menor")
    end

    it "rejects converting a regular transaction into an unpaired transfer" do
      regular_transaction = tx
      destination_account = create(:account, user: user)

      expect {
        patch transaction_path(regular_transaction, locale: :"pt-BR"), params: {
          transaction: {
            transaction_type: "transfer",
            account_id: account.id,
            to_account_id: destination_account.id,
            amount: "150.00",
            date: Date.current.to_s
          }
        }
      }.not_to change(Transaction, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Crie uma nova transferencia")
      expect(regular_transaction.reload).to be_expense
      expect(regular_transaction.transfer_pair).to be_nil
    end

    context "when updating a transfer" do
      let(:destination_account) { create(:account, user: user) }
      let(:new_destination_account) { create(:account, user: user) }
      let(:transfer) do
        Transfers::Create.new.call(
          from_account: account,
          to_account: destination_account,
          amount: 40.00,
          date: Date.current,
          description: "Poupanca"
        ).first
      end

      it "updates both paired rows together" do
        patch transaction_path(transfer, locale: :"pt-BR"), params: {
          transaction: {
            description: "Reserva",
            amount: "75.00",
            date: Date.current.to_s,
            status: "pending",
            account_id: account.id,
            to_account_id: new_destination_account.id
          }
        }

        expect(response).to redirect_to(transactions_path(locale: :"pt-BR"))

        debit = transfer.reload
        credit = debit.transfer_pair.reload
        expect(debit).to have_attributes(
          description: "Reserva",
          amount: 75.00,
          status: "pending",
          account: account,
          transfer_direction: "outgoing"
        )
        expect(credit).to have_attributes(
          description: "Reserva",
          amount: 75.00,
          status: "pending",
          account: new_destination_account,
          transfer_direction: "incoming"
        )
      end

      it "rejects changing a transfer to the same source and destination account" do
        expect {
          patch transaction_path(transfer, locale: :"pt-BR"), params: {
            transaction: {
              amount: "75.00",
              date: Date.current.to_s,
              status: "settled",
              account_id: account.id,
              to_account_id: account.id
            }
          }
        }.not_to change { transfer.reload.amount }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("conta de destino diferente")
      end

      it "rejects invalid transfer amounts without changing either paired row" do
        debit = transfer
        credit = transfer.transfer_pair

        patch transaction_path(transfer, locale: :"pt-BR"), params: {
          transaction: {
            amount: "0",
            date: Date.current.to_s,
            status: "settled",
            account_id: account.id,
            to_account_id: destination_account.id
          }
        }

        expect(response).to have_http_status(:unprocessable_content)
        expect(debit.reload.amount).to eq(40.00)
        expect(credit.reload.amount).to eq(40.00)
      end
    end
  end

  describe "DELETE /transactions/:id" do
    let!(:tx) { create(:transaction, :expense, account: account) }

    it "destroys the transaction" do
      expect { delete transaction_path(tx) }.to change(Transaction, :count).by(-1)
    end

    it "destroys both rows of a paired transfer" do
      destination_account = create(:account, user: user)
      transfer = Transfers::Create.new.call(
        from_account: account,
        to_account: destination_account,
        amount: 25.00,
        date: Date.current,
        description: "Poupanca"
      ).first

      expect { delete transaction_path(transfer) }
        .to change(Transaction, :count).by(-2)
    end

    it "does not destroy another user's transaction" do
      other_tx = create(:transaction, :income, account: create(:account, user: other))
      expect { delete transaction_path(other_tx) }
        .not_to change(Transaction, :count)
      expect(response).to have_http_status(:not_found)
    end
  end
end
