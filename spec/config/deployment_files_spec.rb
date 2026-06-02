require "spec_helper"

RSpec.describe "deployment files" do
  it "uses an asdf-compatible Ruby version file" do
    expect(File.read(".ruby-version")).to eq("4.0.5\n")
  end

  it "defines the Fly.io app, release command, and health check" do
    fly_config = File.read("fly.toml")

    expect(fly_config).to include('app = "fluxo-on-rails"')
    expect(fly_config).to include('primary_region = "gru"')
    expect(fly_config).to include('release_command = "bin/rails db:prepare"')
    expect(fly_config).to include('APP_HOST = "fluxo-on-rails.fly.dev"')
    expect(fly_config).to include("swap_size_mb = 512")
    expect(fly_config).to include("[processes]")
    expect(fly_config).to include('web = "bin/thrust bin/rails server"')
    expect(fly_config).to include('worker = "bin/jobs start"')
    expect(fly_config).to include('processes = ["web"]')
    expect(fly_config).to include("[[vm]]")
    expect(fly_config).to include('size = "shared-cpu-1x"')
    expect(fly_config).to include('memory = "512mb"')
    expect(fly_config).to include('THRUSTER_HTTP_PORT = "3000"')
    expect(fly_config).to include('THRUSTER_TARGET_PORT = "3001"')
    expect(fly_config).not_to include('SOLID_QUEUE_IN_PUMA = "true"')
    expect(fly_config).to include('internal_port = 3000')
    expect(fly_config).to include('force_https = true')
    expect(fly_config).to include('auto_stop_machines = "stop"')
    expect(fly_config).to include("auto_start_machines = true")
    expect(fly_config).to include('min_machines_running = 2')
    expect(fly_config).to include('grace_period = "60s"')
    expect(fly_config).to include('interval = "15s"')
    expect(fly_config).to include('path = "/up"')
    expect(fly_config).to include('timeout = "2s"')
    expect(fly_config).not_to include("DATABASE_URL")
    expect(fly_config).not_to include("RAILS_MASTER_KEY")
  end

  it "builds a production Rails image that starts through Thruster" do
    dockerfile = File.read("Dockerfile")

    expect(dockerfile).to include("FROM docker.io/library/ruby:4.0.5-slim AS base")
    expect(dockerfile).to include("gem install bundler -v 4.0.10")
    expect(dockerfile).to include("libyaml-0-2")
    expect(dockerfile).to include("libyaml-dev")
    expect(dockerfile).to include("DATABASE_URL=postgresql://postgres:postgres@localhost:5432/fluxo_build")
    expect(dockerfile).to include("SECRET_KEY_BASE_DUMMY=1")
    expect(dockerfile).to include('CMD ["bin/thrust", "bin/rails", "server"]')
  end

  it "keeps local secrets and transient files out of Docker build context" do
    dockerignore = File.read(".dockerignore")

    expect(dockerignore).to include(".env*")
    expect(dockerignore).to include("config/master.key")
    expect(dockerignore).to include(".git")
    expect(dockerignore).to include("log/*")
    expect(dockerignore).to include("tmp/*")
    expect(dockerignore).to include("storage/*")
  end

  it "keeps local canary and agent artifacts out of git" do
    gitignore = File.read(".gitignore")

    expect(gitignore).to include(".gstack/")
  end
end
