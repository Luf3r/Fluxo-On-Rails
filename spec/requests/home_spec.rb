require "rails_helper"

RSpec.describe "Home", type: :request do
  it "loads the root page" do
    get root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Fluxo")
  end

  it "loads the root page for an authenticated user" do
    user = create(:user, password: "password123")
    post user_session_path, params: {
      user: { email: user.email, password: "password123" }
    }

    get root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Fluxo")
  end
end
