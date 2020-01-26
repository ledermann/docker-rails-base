FROM ruby:2.6.5-alpine
LABEL maintainer="georg@ledermann.dev"

# Add basic packages
RUN apk add --update --no-cache \
      build-base \
      postgresql-dev \
      git \
      nodejs \
      yarn \
      tzdata \
      file

WORKDIR /app

# Install standard Node modules
COPY package.json yarn.lock /app/
RUN yarn install

# Install standard gems
ADD Gemfile* /app/
RUN bundle config --global frozen 1 && \
    bundle install -j4 --retry 3

#### ONBUILD: Add triggers to the image, executed later while building a child image

# Install Ruby gems (for production only)
ONBUILD ADD Gemfile* /app/
ONBUILD RUN bundle install -j4 --retry 3 --without development:test && \
  # Remove unneeded gems
  bundle clean --force && \
  # Remove unneeded files from installed gems (cached *.gem, *.o, *.c)
  rm -rf /usr/local/bundle/cache/*.gem && \
  find /usr/local/bundle/gems/ -name "*.c" -delete && \
  find /usr/local/bundle/gems/ -name "*.o" -delete

# Install Node modules (for production only)
ONBUILD COPY package.json yarn.lock /app/
ONBUILD RUN yarn install --prod

# Add the Rails app
ONBUILD ADD . /app

# Compile assets with webpacker
ONBUILD RUN RAILS_ENV=production \
            SECRET_KEY_BASE=dummy \
            bundle exec rails webpacker:compile

# Remove folders not needed in resulting image
ONBUILD RUN rm -rf node_modules tmp/cache vendor/bundle test spec
