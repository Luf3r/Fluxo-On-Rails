require "rails_helper"

RSpec.describe AuthenticatedController, type: :controller do
  it "requires Devise authentication before actions" do
    before_action_filters = described_class._process_action_callbacks
      .select { |callback| callback.kind == :before }
      .map(&:filter)

    expect(before_action_filters).to include(:authenticate_user!)
  end

  it "maps missing scoped records to not found responses" do
    expect(described_class.rescue_handlers)
      .to include([ "ActiveRecord::RecordNotFound", :render_not_found ])
  end
end
