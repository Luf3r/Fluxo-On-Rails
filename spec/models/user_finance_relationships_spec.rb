require "rails_helper"

RSpec.describe User, type: :model do
  describe "etapa 03 finance relationships" do
    it { should have_many(:accounts).dependent(:destroy) }
    it { should have_many(:transactions).through(:accounts) }
  end
end
