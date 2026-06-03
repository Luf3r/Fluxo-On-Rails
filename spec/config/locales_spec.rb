require "rails_helper"

RSpec.describe "locale files" do
  REQUIRED_KEYS = %w[
    app.nav.account
    app.nav.accounts
    app.nav.categories
    app.nav.transactions
    date.formats.default
    finance.accounts.errors.initial_balance_too_large
    finance.categories.index.title
    finance.categories.form.no_parent
    finance.categories.notices.destroy_failed
    finance.categories.system_names.groceries
    finance.transactions.index.title
    finance.transactions.filters.submit
    finance.transactions.filters.all_categories
    finance.transactions.filters.all_tags
    finance.transactions.form.category_prompt
    finance.transactions.form.tags_hint
    finance.transactions.form.to_account_prompt
    finance.transactions.form.transfer_hint
    finance.transactions.errors.same_account_transfer
    finance.transactions.errors.amount_too_large
    finance.transactions.errors.destination_required
    finance.transactions.errors.transfer_update_requires_new_record
  ].freeze

  I18n.available_locales.each do |locale|
    it "defines finance navigation and transaction keys for #{locale}" do
      REQUIRED_KEYS.each do |key|
        expect(I18n.exists?(key, locale)).to be(true), "missing #{locale}.#{key}"
      end
    end
  end
end
