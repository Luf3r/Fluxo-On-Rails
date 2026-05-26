# frozen_string_literal: true

class Rack::Attack
  LOGIN_PATH = "/users/sign_in"
  PASSWORD_RESET_PATH = "/users/password"

  self.cache.store = Rails.env.test? ? ActiveSupport::Cache::MemoryStore.new : Rails.cache

  throttle("login/ip", limit: 5, period: 10.minutes) do |request|
    request.ip if post_to?(request, LOGIN_PATH)
  end

  throttle("login/email", limit: 10, period: 10.minutes) do |request|
    normalized_email(request) if post_to?(request, LOGIN_PATH)
  end

  throttle("password_reset/ip", limit: 5, period: 10.minutes) do |request|
    request.ip if post_to?(request, PASSWORD_RESET_PATH)
  end

  throttle("password_reset/email", limit: 5, period: 10.minutes) do |request|
    normalized_email(request) if post_to?(request, PASSWORD_RESET_PATH)
  end

  self.throttled_responder = lambda do |request|
    match_data = request.env["rack.attack.match_data"] || {}
    retry_after = match_data[:period].to_i

    [
      429,
      {
        "Content-Type" => "text/plain; charset=utf-8",
        "Retry-After" => retry_after.to_s
      },
      [ "Throttle limit reached\n" ]
    ]
  end

  def self.normalized_email(request)
    request.params.dig("user", "email").to_s.downcase.strip.presence
  end

  def self.post_to?(request, path)
    request.post? && request.path == path
  end
end
