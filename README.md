# DockerRailsBase

Building Docker images usually takes a long time. This repo contains base images with preinstalled dependencies for [Ruby on Rails](https://rubyonrails.org/), so building a production image will be **2-3 times faster**.


## What?

When using the official Ruby image, building a Docker image for a typical Rails application requires lots of time for installing dependencies - mainly OS packages, Ruby gems, Ruby gems with native extensions (Nokogiri etc.) and Node modules. This is required every time the app needs to be deployed to production.

I was looking for a way to reduce this time, so I created base images that contain most of the dependencies used in my applications.

I've compared build times on my main machine using a typical Rails application. This is the result:

- Based on official Ruby image: **4:50 min**
- Based on DockerRailsBase: **2:07 min**

As you can see, using DockerRailsBase is more than **2 times faster** compared to the official Ruby image. It saves nearly **3min** on every build.

Note: Before starting the build, the base image was not present on my machine, so it was downloaded first. If the base image is already present, the build time is only 1:18min (**3 times faster**).


## How?

This repo is based on the following assumptions:

- Your app is compatible with [Ruby 2.6.5 for Alpine Linux](https://github.com/docker-library/ruby/blob/master/2.6/alpine3.11/Dockerfile)
- Your app uses Ruby on Rails
- Your app installs Node modules with [Yarn](https://yarnpkg.com/)
- Your app compiles JS with [Webpacker](https://github.com/rails/webpacker)
- Your app's Dockerfile uses [multi-stage building](https://docs.docker.com/develop/develop-images/multistage-build/)

There are two Dockerfiles in this repo, one for the first stage (called "Builder") and one for the resulting stage (called "Final").

### Builder stage

Used for installing Ruby gems and Node modules. Includes Git, Node.js and some build tools - all you need to compile assets.

- Based on ruby:2.6.5-alpine
- Adds packages needed for installing gems and compiling assets: Git, Node.js, Yarn, PostgreSQL client, Vips and build tools
- Adds some standard Ruby gems (Rails 6 etc.)
- Adds some standard Node modules (Vue.js etc.)

See [Builder/Dockerfile](./Builder/Dockerfile)


### Final stage

Production image including just the minimum. Prepared for copying app and gems from the Builder stage.

- Based on ruby:2.6.5-alpine
- Adds packages needed for production: postgresql-client, vips, tzdata, file

See [Final/Dockerfile](./Final/Dockerfile)


### Staying up-to-date

Using [Dependabot](https://dependabot.com/), every updated Ruby gem or Node module will lead to an updated image.


### Usage example

```Dockerfile
######################
# Stage: Builder
FROM docker.pkg.github.com/ledermann/docker-rails-base/rails-base-builder:latest as Builder

# Install gems
ADD Gemfile* /app/
RUN bundle install -j4 --retry 3 --without development:test && \
    bundle clean --force

# Install yarn packages
COPY package.json yarn.lock /app/
RUN yarn install --prod

# Add the Rails app
ADD . /app

# Compile assets
RUN RAILS_ENV=production \
    SECRET_KEY_BASE=dummy \
    bundle exec rails webpacker:compile

# Remove folders not needed in resulting image
RUN rm -rf node_modules tmp/cache test

###############################
# Stage Final
FROM docker.pkg.github.com/ledermann/docker-rails-base/rails-base-final:latest

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


## FAQ

### Why not simply use layer caching?

Docker supports layer caching, so for building images it performs just the needed steps: If there is a layer from a former build and nothing has changed, it will be used. But for dependencies, this means: If a single Ruby gem in the application was updated or added, the step with `bundle install` is run again, so **all** gems will be installed again.

Using a prebuilt image improves installing dependencies a lot, because only the different/updated dependencies will be installed - all existing ones will be reused.

### What if my app requires slightly different dependencies?

This doesn't matter:

- A missing Alpine package can be installed via `apk add` inside your app's Dockerfile.
- A missing Node module can be installed via `yarn install` inside your app's Dockerfile.
- A missing Ruby gem can be installed via `bundle install` inside your app's Dockerfile.
