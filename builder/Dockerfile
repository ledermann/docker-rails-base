# syntax = docker/dockerfile:1
FROM ruby:3.4.3-alpine
LABEL maintainer="georg@ledermann.dev"

# Add basic packages
RUN apk add --no-cache \
    build-base \
    gcompat \
    git \
    imagemagick-dev \
    mariadb-dev \
    nodejs-current \
    npm \
    postgresql-dev \
    sqlite-dev \
    tzdata \
    vips-dev \
    yaml-dev \
    yarn

WORKDIR /app

#### Install standard Node modules
COPY package.json yarn.lock /app/
# If your app uses Cypress for end-to-end testing, installing the binary can be slow, so we
# explicitly exclude it from installing (because tests are not run here)
ENV CYPRESS_INSTALL_BINARY=0
# Avoid error "digital envelope routines::initialization error" while compiling assets with Webpack
# due to OpenSSL 3.0 (included in Alpine 3.17+)
ENV NODE_OPTIONS=--openssl-legacy-provider
RUN yarn install --frozen-lockfile
####

##### Install standard gems
COPY Gemfile Gemfile.lock /app/
RUN bundle config --local frozen 1 && \
    bundle install --jobs $(nproc) --retry 3
####

#### ONBUILD: Add triggers to the image, executed later while building a child image

# Arguments for the child image
ONBUILD ARG SKIP_BOOTSNAP_PRECOMPILE

# Copy only the files needed for installing gems
ONBUILD COPY .ruby-version Gemfile Gemfile.lock /app/
ONBUILD COPY vendor/ /app/vendor/

# Install Ruby gems (for production only)
ONBUILD RUN --mount=type=secret,id=bundleconfig,dst=/root/.bundle/config \
    bundle config --local without 'development test' && \
    bundle install --jobs $(nproc) --retry 3 && \
    # Remove unneeded gems
    bundle clean --force && \
    # Remove unneeded files from installed gems (cache, *.o, *.c)
    rm -rf /usr/local/bundle/cache && \
    find /usr/local/bundle -type f \( \
    -name '*.c' -o \
    -name '*.o' -o \
    -name '*.log' -o \
    -name 'gem_make.out' \
    \) -delete && \
    find /usr/local/bundle -name '*.so' -exec strip --strip-unneeded {} +

# Precompile gems with Bootsnap
ONBUILD RUN if [ -z "$SKIP_BOOTSNAP_PRECOMPILE" ]; then \
    bundle exec bootsnap precompile --gemfile ; \
    else \
    echo "Skipped precompiling gems with Bootsnap" ; \
    fi

# Copy the whole application folder into the image
ONBUILD COPY . /app

# Precompile application code with Bootsnap
ONBUILD RUN if [ -z "$SKIP_BOOTSNAP_PRECOMPILE" ]; then \
    bundle exec bootsnap precompile app/ lib/ ; \
    else \
    echo "Skipped precompiling app with Bootsnap" ; \
    fi

# Precompile assets
#
# Notes:
#   1. What exactly "assets:precompile" does depends on your JavaScript bundler
#   2. For an app using encrypted credentials, Rails raises a `MissingKeyError`
#      if the master key is missing. Because on CI there is no master key,
#      we hide the credentials while compiling assets (by renaming them before and after)
#
ONBUILD RUN mv config/credentials.yml.enc config/credentials.yml.enc.bak 2>/dev/null || true
ONBUILD RUN mv config/credentials config/credentials.bak 2>/dev/null || true
ONBUILD RUN --mount=type=secret,id=npmrc,dst=/root/.npmrc \
    --mount=type=secret,id=yarnrc,dst=/root/.yarnrc.yml \
    yarn install
ONBUILD RUN RAILS_ENV=production \
    SECRET_KEY_BASE=dummy \
    RAILS_MASTER_KEY=dummy \
    VITE_RUBY_SKIP_ASSETS_PRECOMPILE_INSTALL=true \
    bundle exec rails assets:precompile
ONBUILD RUN mv config/credentials.yml.enc.bak config/credentials.yml.enc 2>/dev/null || true
ONBUILD RUN mv config/credentials.bak config/credentials 2>/dev/null || true

# Remove folders not needed in resulting image
# This includes `app/javascript` which contains the JavaScript source code.
# Normally it is not needed in the resulting image, because it was compiled
# to `public/`. But if the app uses import maps, the folder is still required
# for pinning and must not be removed.
ONBUILD RUN rm -rf node_modules yarn.lock .yarn .yarnrc.yml vendor/bundle test spec app/packs
ONBUILD RUN if [ ! -f config/importmap.rb ]; then rm -rf app/javascript; fi
