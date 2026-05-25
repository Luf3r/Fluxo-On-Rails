# spec/mailers/budget_mailer_spec.rb
require "rails_helper"

RSpec.describe BudgetMailer, type: :mailer do
  let(:user)     { create(:user, email: "user@example.com", name: "Maria") }
  let(:category) { create(:category, user: user, name: "Alimentação", budget: 1000.00) }

  describe "#alert" do
    let(:mail) { described_class.alert(user, category, 85) }

    it "sends to the user's email" do
      expect(mail.to).to include(user.email)
    end

    it "has a meaningful subject" do
      expect(mail.subject).to include("orçamento").or include("Alimentação").or include("85")
    end

    it "includes the category name in the body" do
      expect(mail.body.encoded).to include("Alimentação")
    end

    it "includes the percentage in the body" do
      expect(mail.body.encoded).to include("85")
    end

    it "includes the user's name" do
      expect(mail.body.encoded).to include("Maria")
    end
  end
end

# spec/mailers/digest_mailer_spec.rb
RSpec.describe DigestMailer, type: :mailer do
  let(:user)    { create(:user, email: "digest@example.com", name: "Carlos") }
  let(:account) { create(:account, user: user, initial_balance: 0) }

  before do
    create(:transaction, :income,  :settled, account: account, amount: 5000, date: Date.current)
    create(:transaction, :expense, :settled, account: account, amount: 2000, date: Date.current)
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
  end
end