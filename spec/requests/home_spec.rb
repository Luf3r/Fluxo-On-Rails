require "rails_helper"

RSpec.describe "Home", type: :request do
  it "loads the root page" do
    get root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Fluxo")
  end

  it "loads the root page in Portuguese" do
    get root_path(locale: :"pt-BR")

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Controle seu dinheiro")
  end

  it "loads the root page in English" do
    get root_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Control your money")
  end

  it "sends a restrictive content security policy" do
    get root_path

    expect(response.headers["Content-Security-Policy"]).to include("default-src 'self'")
    expect(response.headers["Content-Security-Policy"]).to include("object-src 'none'")
    expect(response.headers["Content-Security-Policy"]).to include("form-action 'self'")
    expect(response.headers["Content-Security-Policy"]).to include("frame-ancestors 'none'")
  end

  it "does not expose permissive cross-origin headers by default" do
    get root_path

    expect(response.headers["Access-Control-Allow-Origin"]).to be_nil
    expect(response.headers["Access-Control-Allow-Credentials"]).to be_nil
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
