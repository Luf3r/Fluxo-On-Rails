# syntax=docker/dockerfile:1

FROM docker.io/library/ruby:4.0.5-slim AS base

WORKDIR /rails

ENV BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test" \
    RAILS_ENV="production"

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y curl libjemalloc2 libpq5 libvips libyaml-0-2 postgresql-client && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

FROM base AS build

RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y build-essential git libpq-dev libyaml-dev pkg-config && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

COPY Gemfile Gemfile.lock .ruby-version ./
RUN gem install bundler -v 4.0.10 && \
    bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

COPY . .
RUN DATABASE_URL=postgresql://postgres:postgres@localhost:5432/fluxo_build \
    SECRET_KEY_BASE_DUMMY=1 \
    bin/rails assets:precompile

FROM base

RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash

COPY --from=build /usr/local/bundle /usr/local/bundle
COPY --from=build --chown=rails:rails /rails /rails

RUN mkdir -p log storage tmp/pids tmp/cache && \
    chown -R rails:rails log storage tmp

USER rails:rails

EXPOSE 3000
CMD ["bin/thrust", "bin/rails", "server"]
