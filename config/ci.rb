# Run using bin/ci

ENV["RUBOCOP_CACHE_ROOT"] ||= "tmp/rubocop"

CI.run do
  step "Setup", "bundle check"

  step "Database: Test migrations", "RAILS_ENV=test bin/rails db:migrate"

  step "Tests: RSpec", "bundle exec rspec"

  step "Style: Ruby", "bin/rubocop"

  step "Security: Gem audit", "bin/bundler-audit"
  step "Security: Importmap vulnerability audit", "bin/importmap audit"
  step "Security: Brakeman code analysis", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"

  step "Boot: Zeitwerk", "RAILS_ENV=test bin/rails zeitwerk:check"

  step "Assets: Production precompile",
    "RAILS_ENV=production DATABASE_URL=${DATABASE_URL:-${TEST_DATABASE_URL:-postgresql://postgres:postgres@localhost:5432/fluxo_test}} SECRET_KEY_BASE_DUMMY=1 bin/rails assets:precompile"

  # Optional: set a green GitHub commit status to unblock PR merge.
  # Requires the `gh` CLI and `gh extension install basecamp/gh-signoff`.
  # if success?
  #   step "Signoff: All systems go. Ready for merge and deploy.", "gh signoff"
  # else
  #   failure "Signoff: CI failed. Do not merge or deploy.", "Fix the issues and try again."
  # end
end
