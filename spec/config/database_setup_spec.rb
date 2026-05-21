require "spec_helper"

RSpec.describe "database setup" do
  let(:database_config) { File.read(File.expand_path("../../config/database.yml", __dir__)) }

  it "uses Neon URLs instead of local PostgreSQL defaults" do
    expect(database_config).to include("def required_database_url(key, environment)")
    expect(database_config).to include('development_database_url = required_database_url("DATABASE_URL", "development")')
    expect(database_config).to include('test_database_url = required_database_url("TEST_DATABASE_URL", "test")')
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
end
