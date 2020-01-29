![Build images](https://github.com/ledermann/docker-rails-base/workflows/Build%20images/badge.svg)

# DockerRailsBase

Building Docker images usually takes a long time. This repo contains base images with preinstalled dependencies for [Ruby on Rails](https://rubyonrails.org/), so building a production image will be **2-3 times faster**.


## What?

When using the official Ruby image, building a Docker image for a typical Rails application requires lots of time for installing dependencies - mainly OS packages, Ruby gems, Ruby gems with native extensions (Nokogiri etc.) and Node modules. This is required every time the app needs to be deployed to production.

I was looking for a way to reduce this time, so I created base images that contain most of the dependencies used in my applications.

And while I'm at it, I also moved as much as possible from the app-specific Dockerfile into the base image by using [ONBUILD](https://docs.docker.com/engine/reference/builder/#onbuild) triggers. This makes the Dockerfile in my apps small and simple.


## Performance

I compared building times using a typical Rails application. This is the result on my local machine:

- Based on official Ruby image: **4:50 min**
- Based on DockerRailsBase: **1:57 min**

As you can see, using DockerRailsBase is more than **2 times faster** compared to the official Ruby image. It saves nearly **3min** on every build.

Note: Before I started timing, the base image was not available on my machine, so it was downloaded first, which took some time. If the base image is already available, the building time is only 1:18min (**3 times faster**).


## How?

This repo is based on the following assumptions:

- Your app is compatible with [Ruby 2.6.5 for Alpine Linux](https://github.com/docker-library/ruby/blob/master/2.6/alpine3.11/Dockerfile)
- Your app uses Ruby on Rails 6
- Your app uses PostgreSQL
- Your app installs Node modules with [Yarn](https://yarnpkg.com/)
- Your app compiles JS with [Webpacker](https://github.com/rails/webpacker)

To build a very small production image, [multi-stage building](https://docs.docker.com/develop/develop-images/multistage-build/) is used. There are two Dockerfiles in this repo, one for the first stage (called "Builder") and one for the resulting stage (called "Final").

### Builder stage

Used for installing Ruby gems and Node modules. Includes Git, Node.js and some build tools - all we need to compile assets.

- Based on ruby:2.6.5-alpine
- Adds packages needed for installing gems and compiling assets: Git, Node.js, Yarn, PostgreSQL client and build tools
- Adds some standard Ruby gems (Rails 6 etc.)
- Adds some standard Node modules (Vue.js etc.)
- Via ONBUILD triggers it installs missing gems and Node modules, then compiles the assets

See [Builder/Dockerfile](./Builder/Dockerfile)


### Final stage

Used to build the production image which includes just the minimum.

- Based on ruby:2.6.5-alpine
- Adds packages needed for production: postgresql-client, tzdata, file
- Via ONBUILD triggers it mainly copies the app and gems from the "Builder" stage

See [Final/Dockerfile](./Final/Dockerfile)


### Staying up-to-date

Using [Dependabot](https://dependabot.com/), every updated Ruby gem or Node module will lead to an updated image.


### Usage example

```Dockerfile
FROM docker.pkg.github.com/ledermann/docker-rails-base/rails-base-builder:latest AS Builder
FROM docker.pkg.github.com/ledermann/docker-rails-base/rails-base-final:latest
USER app
CMD ["startup.sh"] # defined in the app image
```

Yes, this is the complete Dockerfile of the Rails app. It's so simple because the work is done by ONBUILD triggers.


## FAQ

### Why not simply use layer caching?

Docker supports layer caching, so for building images it performs just the needed steps: If there is a layer from a former build and nothing has changed, it will be used. But for dependencies, this means: If a single Ruby gem in the application was updated or added, the step with `bundle install` is run again, so **all** gems will be installed again.

Using a prebuilt image improves installing dependencies a lot, because only the different/updated dependencies will be installed - all existing ones will be reused.

### What if my app requires slightly different dependencies?

This doesn't matter:

- A missing Alpine package can be installed with `apk add` inside your app's Dockerfile.
- A missing Node module (or version) will be installed with `yarn install` via the ONBUILD trigger.
- A missing Ruby gem (or version) will be installed with `bundle install` via the ONBUILD trigger.

### There are gems included that my app doesn't need. Will they bloat the resulting image?

No. In the build stage there is a `bundle clean --force`, which uninstalls all gems not referenced in the app's Gemfile.
