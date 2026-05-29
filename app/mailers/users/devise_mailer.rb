module Users
  class DeviseMailer < Devise::Mailer
    protected

    def devise_mail(record, action, opts = {}, &block)
      I18n.with_locale(preferred_locale_for(record)) do
        super
      end
    end

    private

    def preferred_locale_for(record)
      locale = record.respond_to?(:preferred_locale) ? record.preferred_locale : nil

      locale.presence_in(I18n.available_locales.map(&:to_s)) || I18n.default_locale
    end
  end
end
