require "spec_helper"

RSpec.describe "database setup" do
  let(:database_config) { File.read(File.expand_path("../../config/database.yml", __dir__)) }
  let(:application_config) { File.read(File.expand_path("../../config/application.rb", __dir__)) }

  it "uses Neon for runtime and local PostgreSQL as the test default" do
    expect(database_config).to include("def required_database_url(key, environment)")
    expect(database_config).to include('development_database_url = required_database_url("DATABASE_URL", "development")')
    expect(database_config).to include('test_database_url = ENV.fetch("TEST_DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/fluxo_test")')
    expect(database_config).to include("url: <%= development_database_url %>")
    expect(database_config).to include("url: <%= test_database_url %>")
    expect(database_config).not_to include("POSTGRES_HOST")
    expect(database_config).not_to include("fluxo_rails_development")
  end

  it "keeps the Rails schema free of legacy Prisma tables" do
    schema = File.read(File.expand_path("../../db/schema.rb", __dir__))

    expect(schema).not_to include('create_table "User"')
    expect(schema).not_to include('create_table "_prisma_migrations"')
  end

  it "uses UUID primary keys for application-owned tables and generated references" do
    schema = File.read(File.expand_path("../../db/schema.rb", __dir__))
    migration_sources = Dir[File.expand_path("../../db/migrate/*.rb", __dir__)].sort.map { |path| File.read(path) }.join("\n")
    application_create_table_lines = migration_sources.scan(/create_table :\w+[^\n]*/)
      .reject { |line| line.include?("create_table :solid_") }

    expect(schema).to include('create_table "users", id: :uuid, default: nil')
    expect(application_create_table_lines).to all(include("id: :uuid, default: nil"))
    expect(application_config).to include("primary_key_type: :uuid")
  end

  it "creates Solid infrastructure tables through primary migrations for shared production databases" do
    migration_sources = Dir[File.expand_path("../../db/migrate/*.rb", __dir__)].sort.map { |path| File.read(path) }.join("\n")

    expect(migration_sources).to include('create_table :solid_queue_recurring_tasks')
    expect(migration_sources).to include('create_table :solid_cache_entries')
    expect(migration_sources).to include('create_table :solid_cable_messages')
  end
end
