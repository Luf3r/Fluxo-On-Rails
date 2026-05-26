# spec/services/reports/monthly_pdf_spec.rb
require "rails_helper"
require "open3"

RSpec.describe Reports::MonthlyPdf, type: :service do
  let(:user)    { create(:user, name: "João Silva") }
  let(:account) { create(:account, user: user, initial_balance: 0) }
  let(:month)   { Date.new(2025, 1, 1) }

  subject(:service) { described_class.new(user, month) }

  before do
    create(:transaction, :income,  :settled, account: account, amount: 4000, date: month)
    create(:transaction, :expense, :settled, account: account, amount: 1500, date: month)
    other_account = create(:account, user: create(:user, name: "Other User"), initial_balance: 0)
    create(:transaction, :income, :settled, account: other_account,
           amount: 99_999, description: "Other User Private Income", date: month)
  end

  describe "#generate" do
    it "returns a non-empty string (raw PDF bytes)" do
      result = service.generate
      expect(result).to be_a(String)
      expect(result).not_to be_empty
    end

    it "returns valid PDF magic bytes" do
      result = service.generate
      expect(result.bytes.first(4)).to eq("%PDF".bytes)
    end

    it "does not raise for a month with no transactions" do
      user_empty  = create(:user)
      empty_month = Date.new(2024, 6, 1)
      result = Reports::MonthlyPdf.new(user_empty, empty_month).generate
      expect(result.bytes.first(4)).to eq("%PDF".bytes)
    end
  end

  describe "content" do
    # These tests parse the PDF to text via pdftotext or Prawn introspection.
    # Skip in environments without pdftotext installed.
    let(:pdf_text) do
      pdf_bytes  = service.generate
      tmp        = Tempfile.new([ "report", ".pdf" ])
      tmp.binmode
      tmp.write(pdf_bytes)
      tmp.close
      Open3.capture2("pdftotext", tmp.path, "-").first
    end

    before do
      skip "pdftotext not available" unless system("which", "pdftotext", out: File::NULL, err: File::NULL)
    end

    it "includes the user's name" do
      expect(pdf_text).to include("João Silva")
    end

    it "includes the month reference" do
      expect(pdf_text).to include("Janeiro")
    end

    it "includes total income" do
      expect(pdf_text).to include("4000")
    end

    it "includes total expense" do
      expect(pdf_text).to include("1500")
    end

    it "does not include another user's financial data" do
      expect(pdf_text).not_to include("Other User")
      expect(pdf_text).not_to include("Private Income")
      expect(pdf_text).not_to include("99999")
    end
  end
end
