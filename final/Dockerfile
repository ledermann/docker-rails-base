# syntax=docker/dockerfile:1
# check=error=true

FROM ruby:4.0.7-alpine

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

# Add user
ONBUILD RUN addgroup -g 1000 -S app && \
      adduser -u 1000 -S app -G app

# Copy app with gems from former build stage
ONBUILD COPY --from=builder --chown=app:app /usr/local/bundle/ /usr/local/bundle/
ONBUILD COPY --from=builder --chown=app:app /app /app

# Write GIT meta data from arguments to env vars
ONBUILD ARG COMMIT_SHA
ONBUILD ARG COMMIT_TIME
ONBUILD ARG COMMIT_VERSION
ONBUILD ARG COMMIT_BRANCH

ONBUILD ENV COMMIT_SHA=${COMMIT_SHA}
ONBUILD ENV COMMIT_TIME=${COMMIT_TIME}
ONBUILD ENV COMMIT_VERSION=${COMMIT_VERSION}
ONBUILD ENV COMMIT_BRANCH=${COMMIT_BRANCH}

# Write the same GIT meta data to a file. A container keeps the env vars it
# was created with, so a tool that recreates it from its old configuration
# after an update carries over the values of the old image. The file always
# belongs to the image that runs. It lies outside /app to never collide with
# a file of the app.
ONBUILD RUN printf 'COMMIT_SHA=%s\nCOMMIT_TIME=%s\nCOMMIT_VERSION=%s\nCOMMIT_BRANCH=%s\n' \
      "${COMMIT_SHA}" "${COMMIT_TIME}" "${COMMIT_VERSION}" "${COMMIT_BRANCH}" \
      > /etc/build-info
