# DockerRailsBase

Base images to build Docker container for Ruby on Rails applications

- Based on the official [Ruby image](https://hub.docker.com/_/ruby/) for Ruby 2.6.5 (Alpine)
- Supports multi stage builds
  - Builder stage: Adds packages needed for building (git, Node.js, Yarn, PostgreSQL client, Vips and build tools) and standard gems
  - Final stage: Adds packages needed for production (postgresql-client, vips, tzdata, file)


Example:

```Dockerfile
######################
# Stage: Builder
FROM docker.pkg.github.com/ledermann/docker-rails-base/rails-base-builder:latest as Builder

ENV BUNDLE_WITHOUT=development:test
ENV RAILS_ENV=production
ENV SECRET_KEY_BASE=just-for-assets-compiling

# Install gems
ADD Gemfile* /app/
RUN bundle config --global frozen 1 && \
  bundle install -j4 --retry 3 && \
  bundle clean --force

# Install yarn packages
COPY package.json yarn.lock /app/
RUN yarn install

# Add the Rails app
ADD . /app

# Compile assets
RUN bundle exec rails webpacker:compile

# Remove folders not needed in resulting image
RUN rm -rf node_modules tmp/cache vendor/bundle test

###############################
# Stage Final
FROM docker.pkg.github.com/ledermann/docker-rails-base/rails-base-final:latest

ENV RAILS_LOG_TO_STDOUT=true
ENV RAILS_SERVE_STATIC_FILES=true

# Add user
RUN addgroup -g 1000 -S app && \
    adduser -u 1000 -S app -G app
USER app

# Copy app with gems from former build stage
COPY --from=Builder /usr/local/bundle/ /usr/local/bundle/
COPY --from=Builder --chown=app:app /app /app

WORKDIR /app

# Expose Puma port
EXPOSE 3000
```
