class ApplicationController < ActionController::Base
  # Keep legacy Internet Explorer out without blocking mobile device emulators that
  # report old Chrome versions while running on a modern browser engine.
  allow_browser versions: { ie: false }

  around_action :switch_locale
  before_action :assign_registration_locale, if: :devise_registration_create?
  before_action :configure_permitted_parameters, if: :devise_controller?

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  protected

  def switch_locale(&action)
    locale = params[:locale].presence_in(I18n.available_locales.map(&:to_s)) || I18n.default_locale
    I18n.with_locale(locale, &action)
  end

  def default_url_options
    return {} if I18n.locale == I18n.default_locale

    { locale: I18n.locale }
  end

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :name, :currency, :preferred_locale ])
    devise_parameter_sanitizer.permit(:account_update, keys: [ :name, :currency, :preferred_locale ])
  end

  def devise_registration_create?
    devise_controller? && controller_name == "registrations" && action_name == "create"
  end

  def assign_registration_locale
    params[:user] ||= {}
    return unless params[:user].is_a?(ActionController::Parameters) ||
      params[:user].is_a?(Hash)

    params[:user][:preferred_locale] = I18n.locale.to_s
  end
end
