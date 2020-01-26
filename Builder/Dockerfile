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
