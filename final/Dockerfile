# syntax=docker/dockerfile:1
# check=error=true

FROM ruby:3.4.8-alpine
LABEL maintainer="georg@ledermann.dev"

# Add basic packages
RUN apk add --no-cache \
      brotli-libs \
      gcompat \
      jemalloc \
      postgresql-client \
      tzdata

# Configure Rails
ENV RAILS_LOG_TO_STDOUT=true \
      RAILS_SERVE_STATIC_FILES=true \
      RAILS_ENV=production

WORKDIR /app

# Expose Puma port
EXPOSE 3000

# Enable jemalloc for reduced memory usage and latency
ENV LD_PRELOAD=/usr/lib/libjemalloc.so.2

# Write GIT meta data from arguments to env vars
ONBUILD ARG COMMIT_SHA
ONBUILD ARG COMMIT_TIME
ONBUILD ARG COMMIT_VERSION
ONBUILD ARG COMMIT_BRANCH

ONBUILD ENV COMMIT_SHA=${COMMIT_SHA}
ONBUILD ENV COMMIT_TIME=${COMMIT_TIME}
ONBUILD ENV COMMIT_VERSION=${COMMIT_VERSION}
ONBUILD ENV COMMIT_BRANCH=${COMMIT_BRANCH}

# Add user
ONBUILD RUN addgroup -g 1000 -S app && \
      adduser -u 1000 -S app -G app

# Copy app with gems from former build stage
ONBUILD COPY --from=builder --chown=app:app /usr/local/bundle/ /usr/local/bundle/
ONBUILD COPY --from=builder --chown=app:app /app /app
