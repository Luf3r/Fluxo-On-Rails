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
