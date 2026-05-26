# spec/services/transfers/create_spec.rb
require "rails_helper"

RSpec.describe Transfers::Create, type: :service do
  subject(:service) { described_class.new }

  let(:user)         { create(:user) }
  let(:from_account) { create(:account, user: user, initial_balance: 1000.00) }
  let(:to_account)   { create(:account, user: user, initial_balance: 0.00) }

  let(:valid_attrs) do
    {
      from_account: from_account,
      to_account:   to_account,
      amount:       300.00,
      date:         Date.current,
      description:  "Transferência poupança"
    }
  end

  describe "#call" do
    it "creates two transactions" do
      expect { service.call(**valid_attrs) }.to change(Transaction, :count).by(2)
    end

    it "creates a debit (expense) on the source account" do
      service.call(**valid_attrs)
      debit = from_account.transactions.last
      expect(debit.transaction_type).to eq("expense")
      expect(debit.amount).to eq(300.00)
    end

    it "creates a credit (income) on the destination account" do
      service.call(**valid_attrs)
      credit = to_account.transactions.last
      expect(credit.transaction_type).to eq("income")
      expect(credit.amount).to eq(300.00)
    end

    it "links the two transactions via transfer_pair" do
      service.call(**valid_attrs)
      debit  = from_account.transactions.last
      credit = to_account.transactions.last
      expect(debit.transfer_pair).to eq(credit)
      expect(credit.transfer_pair).to eq(debit)
    end

    it "reduces source account balance" do
      service.call(**valid_attrs)
      expect(from_account.current_balance).to eq(700.00)
    end

    it "increases destination account balance" do
      service.call(**valid_attrs)
      expect(to_account.current_balance).to eq(300.00)
    end

    it "sets correct date on both transactions" do
      date = Date.new(2025, 6, 15)
      service.call(**valid_attrs.merge(date: date))
      expect(from_account.transactions.last.date).to eq(date)
      expect(to_account.transactions.last.date).to eq(date)
    end

    context "atomicity" do
      subject(:service) { described_class.new(transaction_executor: transaction_executor) }

      let(:transaction_executor) do
        Class.new do
          def initialize
            @save_count = 0
          end

          def save!(transaction)
            @save_count += 1
            raise ActiveRecord::RecordInvalid, transaction if @save_count == 2

            transaction.save!
          end
        end.new
      end

      it "rolls back both records if the injected executor fails on the second save" do
        initial_count = Transaction.count

        expect { service.call(**valid_attrs) }
          .to raise_error(ActiveRecord::RecordInvalid)
        expect(Transaction.count).to eq(initial_count)
      end
    end

    context "with invalid amount" do
      it "raises an error for zero amount" do
        expect { service.call(**valid_attrs.merge(amount: 0)) }
          .to raise_error(ActiveRecord::RecordInvalid)
      end

      it "raises an error for negative amount" do
        expect { service.call(**valid_attrs.merge(amount: -50)) }
          .to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context "with accounts from different users" do
      let(:other_user)    { create(:user) }
      let(:other_account) { create(:account, user: other_user) }

      it "raises an authorization error" do
        expect {
          service.call(**valid_attrs.merge(to_account: other_account))
        }.to raise_error(Transfers::Create::UnauthorizedTransferError)
      end
    end
  end
end
