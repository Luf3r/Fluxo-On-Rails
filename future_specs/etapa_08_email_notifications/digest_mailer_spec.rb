# spec/mailers/digest_mailer_spec.rb
require "rails_helper"

RSpec.describe DigestMailer, type: :mailer do
  let(:user)    { create(:user, email: "digest@example.com", name: "Carlos") }
  let(:account) { create(:account, user: user, initial_balance: 0) }

  before do
    create(:transaction, :income,  :settled, account: account, amount: 5000, date: Date.current)
    create(:transaction, :expense, :settled, account: account, amount: 2000, date: Date.current)
    other_account = create(:account, user: create(:user, name: "Other User"), initial_balance: 0)
    create(:transaction, :income, :settled, account: other_account,
           amount: 99_999, description: "Other User Private Income", date: Date.current)
  end

  describe "#monthly" do
    let(:mail) { described_class.monthly(user, Date.current.prev_month) }

    it "sends to the user's email" do
      expect(mail.to).to include(user.email)
    end

    it "has a subject referencing the month" do
      expect(mail.subject).to include("Resumo").or include(Date.current.prev_month.strftime("%B"))
    end

    it "includes the user name" do
      expect(mail.body.encoded).to include("Carlos")
    end

    it "does not include another user's financial data" do
      expect(mail.body.encoded).not_to include("Other User")
      expect(mail.body.encoded).not_to include("Private Income")
      expect(mail.body.encoded).not_to include("99999")
    end
  end
end
