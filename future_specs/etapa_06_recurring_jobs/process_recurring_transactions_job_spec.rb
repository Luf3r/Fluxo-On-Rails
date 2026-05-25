# spec/jobs/process_recurring_transactions_job_spec.rb
require "rails_helper"

RSpec.describe ProcessRecurringTransactionsJob, type: :job do
  let(:user)    { create(:user) }
  let(:account) { create(:account, user: user) }

  def make_rule(next_date: Date.current, frequency: "monthly", **opts)
    source_tx = create(:transaction, :expense, :settled, account: account, amount: 500)
    create(:recurring_rule, transaction: source_tx, next_date: next_date,
           frequency: frequency, active: true, **opts)
  end

  describe "#perform" do
    context "with rules due today" do
      let!(:rule) { make_rule }

      it "creates a new child transaction" do
        expect { described_class.new.perform }
          .to change(Transaction, :count).by(1)
      end

      it "copies amount from the source transaction" do
        described_class.new.perform
        last_tx = Transaction.order(:created_at).last
        expect(last_tx.amount).to eq(500)
      end

      it "sets the new transaction date to rule.next_date" do
        described_class.new.perform
        last_tx = Transaction.order(:created_at).last
        expect(last_tx.date).to eq(Date.current)
      end

      it "advances next_date on the rule" do
        expect { described_class.new.perform }
          .to change { rule.reload.next_date }
      end

      it "links the new transaction to the recurring rule" do
        described_class.new.perform
        last_tx = Transaction.order(:created_at).last
        expect(last_tx.recurring_rule_id).to eq(rule.id)
      end
    end

    context "with rules due in the future" do
      let!(:future_rule) { make_rule(next_date: 1.week.from_now) }

      it "does not process future rules" do
        expect { described_class.new.perform }.not_to change(Transaction, :count)
      end
    end

    context "with inactive rules" do
      let!(:inactive_rule) { make_rule.tap { |r| r.update!(active: false) } }

      it "skips inactive rules" do
        expect { described_class.new.perform }.not_to change(Transaction, :count)
      end
    end

    context "with multiple rules" do
      let!(:rule1) { make_rule }
      let!(:rule2) { make_rule }
      let!(:rule3) { make_rule(next_date: 1.week.from_now) }

      it "processes all due rules" do
        expect { described_class.new.perform }.to change(Transaction, :count).by(2)
      end
    end

    context "when one rule fails" do
      let!(:good_rule) { make_rule }
      let!(:bad_rule)  { make_rule }

      before do
        call_count = 0
        allow_any_instance_of(RecurringRule).to receive(:advance_next_date!) do
          call_count += 1
          raise StandardError, "simulated failure" if call_count == 1
        end
      end

      it "continues processing the remaining rules" do
        expect { described_class.new.perform }
          .to change(Transaction, :count).by_at_least(1)
      end

      it "logs the error" do
        expect(Rails.logger).to receive(:error).at_least(:once)
        described_class.new.perform
      end
    end

    context "with end_date reached" do
      let!(:rule) { make_rule(end_date: Date.current) }

      it "creates the last transaction" do
        expect { described_class.new.perform }.to change(Transaction, :count).by(1)
      end

      it "marks the rule as inactive" do
        described_class.new.perform
        expect(rule.reload.active).to be(false)
      end
    end
  end

  describe "scheduling" do
    it "is enqueued on the default queue" do
      expect(described_class.new.queue_name).to eq("default")
    end
  end
end