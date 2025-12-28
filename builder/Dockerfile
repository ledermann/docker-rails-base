# syntax=docker/dockerfile:1
# check=error=true

FROM ruby:4.0.0-alpine
LABEL maintainer="georg@ledermann.dev"

# Add basic packages
RUN apk add --no-cache \
    bash \
    build-base \
    curl \
    gcompat \
    git \
    imagemagick-dev \
    mariadb-dev \
    nodejs-current \
    npm \
    postgresql-dev \
    sqlite-dev \
    tzdata \
    unzip \
    vips-dev \
    yaml-dev

WORKDIR /app

# Create dummy files/directories to prevent COPY errors if not present in the app
RUN mkdir -p .yarn && \
    echo '{"name":"dummy","private":true}' > package.json

# Install Bun
RUN curl -fsSL https://bun.sh/install | bash && \
    ln -s /root/.bun/bin/bun /usr/local/bin/bun && \
    bun --version

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
    # Remove unneeded files from installed gems (cache, .git, *.o, *.c)
    rm -rf /usr/local/bundle/cache && \
    rm -rf /usr/local/bundle/bundler/gems/*/.git && \
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

# Install JavaScript dependencies
ONBUILD COPY package.json* yarn.lock* .yarnrc.yml* bun.lock* /app/
ONBUILD COPY .yarn .yarn
ONBUILD RUN --mount=type=secret,id=npmrc,dst=/root/.npmrc \
    --mount=type=secret,id=yarnrc,dst=/root/.yarnrc.yml \
    # If your app uses Cypress for end-to-end testing, installing the binary can be slow, so we
    # explicitly exclude it from installing (because tests are not run here)
    export CYPRESS_INSTALL_BINARY=0 && \
    # Detect and use the appropriate package manager
    if [ -f bun.lockb ] || [ -f bun.lock ]; then \
    echo "Installing dependencies with Bun..." && \
    bun install --frozen-lockfile; \
    elif [ -f yarn.lock ]; then \
    echo "Installing dependencies with Yarn..." && \
    corepack enable && \
    yarn install --frozen-lockfile; \
    else \
    echo "No lock file found, skipping JavaScript dependencies installation..."; \
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
ONBUILD RUN RAILS_ENV=production \
    SECRET_KEY_BASE="dummy-secret-for-assets-precompile" \
    VITE_RUBY_SKIP_ASSETS_PRECOMPILE_INSTALL=true \
    ./bin/rails assets:precompile && \
    # remove runtime Bootsnap cache unless explicitly told not to
    if [ -n "$SKIP_BOOTSNAP_PRECOMPILE" ]; then \
    rm -rf ./tmp/cache/bootsnap; \
    fi

# Remove folders not needed in resulting image
# This includes `app/javascript` which contains the JavaScript source code.
# Normally it is not needed in the resulting image, because it was compiled
# to `public/`. But if the app uses import maps, the folder is still required
# for pinning and must not be removed.
ONBUILD RUN rm -rf node_modules yarn.lock .yarn .yarnrc.yml bun.lock bun.lockb vendor/bundle test spec app/packs
ONBUILD RUN if [ ! -f config/importmap.rb ]; then rm -rf app/javascript; fi
