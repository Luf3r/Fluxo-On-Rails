require "json"
require "open3"
require "spec_helper"

RSpec.describe "production environment configuration" do
  it "uses deploy environment variables for host authorization, mailer URLs, and SMTP" do
    config = production_config(
      "APP_HOST" => "fluxo.example",
      "APP_PROTOCOL" => "https",
      "MAILER_FROM" => "Fluxo <verified-sender@example.net>",
      "SMTP_ADDRESS" => "smtp.example",
      "SMTP_AUTHENTICATION" => "plain",
      "SMTP_DOMAIN" => "fluxo.example",
      "SMTP_ENABLE_STARTTLS_AUTO" => "false",
      "SMTP_PASSWORD" => "secret-password",
      "SMTP_PORT" => "2525",
      "SMTP_USERNAME" => "mailer"
    )

    expect(config[:default_url_options]).to eq(host: "fluxo.example", protocol: "https")
    expect(config[:delivery_method]).to eq("smtp")
    expect(config[:perform_deliveries]).to be(true)
    expect(config[:devise_mailer_sender]).to eq("Fluxo <verified-sender@example.net>")
    expect(config[:application_mailer_from]).to eq("Fluxo <verified-sender@example.net>")
    expect(config[:hosts]).to include("fluxo.example")
    expect(config[:host_authorization_excludes_up]).to be(true)
    expect(config[:ssl_redirect_excludes_up]).to be(true)
    expect(config[:smtp_settings]).to include(
      address: "smtp.example",
      authentication: "plain",
      domain: "fluxo.example",
      enable_starttls_auto: "false",
      password: "secret-password",
      port: "2525",
      user_name: "mailer"
    )
  end

  it "disables outbound email delivery when SMTP is not configured yet" do
    config = production_config(
      "SMTP_ADDRESS" => nil,
      "SMTP_AUTHENTICATION" => nil,
      "SMTP_DOMAIN" => nil,
      "SMTP_ENABLE_STARTTLS_AUTO" => nil,
      "SMTP_PASSWORD" => nil,
      "SMTP_PORT" => nil,
      "SMTP_USERNAME" => nil
    )

    expect(config[:delivery_method]).to eq("test")
    expect(config[:perform_deliveries]).to be(false)
    expect(config[:smtp_settings]).not_to include(:address, :user_name, :password)
  end

  def production_config(env)
    script = <<~RUBY
      require "json"

      smtp_settings = Rails.application.config.action_mailer.smtp_settings || {}
      host_authorization_exclusion = Rails.application.config.host_authorization&.fetch(:exclude, nil)
      ssl_redirect_exclusion = Rails.application.config.ssl_options&.dig(:redirect, :exclude)

      puts JSON.generate(
        default_url_options: Rails.application.config.action_mailer.default_url_options,
        delivery_method: Rails.application.config.action_mailer.delivery_method,
        perform_deliveries: Rails.application.config.action_mailer.perform_deliveries,
        devise_mailer_sender: Devise.mailer_sender,
        application_mailer_from: ApplicationMailer.default_params[:from],
        hosts: Rails.application.config.hosts,
        host_authorization_excludes_up: host_authorization_exclusion&.call(
          ActionDispatch::Request.new(Rack::MockRequest.env_for("/up"))
        ) || false,
        ssl_redirect_excludes_up: ssl_redirect_exclusion&.call(
          ActionDispatch::Request.new(Rack::MockRequest.env_for("/up"))
        ) || false,
        smtp_settings: smtp_settings.transform_values(&:to_s)
      )
    RUBY

    default_env = {
      "APP_HOST" => "fluxo.example",
      "APP_PROTOCOL" => "https",
      "DATABASE_URL" => "postgresql://postgres:postgres@localhost:5432/fluxo_test",
      "RAILS_ENV" => "production",
      "SECRET_KEY_BASE_DUMMY" => "1"
    }

    stdout, stderr, status = Open3.capture3(default_env.merge(env), "bin/rails", "runner", script)

    expect(status).to be_success, stderr

    JSON.parse(stdout, symbolize_names: true)
  end
end
