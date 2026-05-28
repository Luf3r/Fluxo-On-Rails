class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  around_action :switch_locale
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
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :name, :currency ])
  end
end
