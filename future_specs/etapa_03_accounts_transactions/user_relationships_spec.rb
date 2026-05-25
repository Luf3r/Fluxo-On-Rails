require "rails_helper"

RSpec.describe User, type: :model do
  describe "future finance relationships" do
    it { should have_many(:accounts).dependent(:destroy) }
    it { should have_many(:transactions).through(:accounts) }
    it { should have_many(:categories) }
    it { should have_many(:tags) }
    it { should have_many(:goals) }
  end
end
