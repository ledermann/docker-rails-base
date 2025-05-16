[![Build images](https://github.com/ledermann/docker-rails-base/actions/workflows/ci.yml/badge.svg)](https://github.com/ledermann/docker-rails-base/actions/workflows/ci.yml)

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

# Requirements

This repo is based on the following assumptions:

- Your Docker host is compatible with [Alpine Linux 3.21](https://www.alpinelinux.org/posts/Alpine-3.21.0-released.html), which requires Docker 20.10.0 or later
- Your app is compatible with [Ruby 3.4 for Alpine Linux](https://github.com/docker-library/ruby/blob/master/3.4/alpine3.21/Dockerfile)
- Your app uses Ruby on Rails 7.1 or later (including Rails 8.0)
- Your app uses PostgreSQL, SQLite or MySQL/MariaDB
- Your app installs Node modules with [Yarn](https://yarnpkg.com/)
- Your app bundles JavaScript with `rails assets:precompile`. This works with [Vite Ruby](https://github.com/ElMassimo/vite_ruby), [Webpacker](https://github.com/rails/webpacker), [Asset pipeline (Sprockets)](https://github.com/rails/sprockets-rails) and others.

If your project differs from this, I suggest to fork this project and create your own base image.

## How?

It uses [multi-stage building](https://docs.docker.com/develop/develop-images/multistage-build/) to build a very small production image. There are two Dockerfiles in this repo, one for the first stage (called `builder`) and one for the resulting stage (called `final`).

### Builder stage

The `builder` stage installs Ruby gems and Node modules. It also includes Git, Node.js and some build tools - all we need to compile assets.

- Based on [ruby:3.4.4-alpine](https://github.com/docker-library/ruby/blob/master/3.4/alpine3.21/Dockerfile)
- Adds packages needed for installing gems and compiling assets: Git, Node.js, Yarn, PostgreSQL client and build tools
- Adds some default Ruby gems (Rails 8.0 etc., see [Gemfile](./builder/Gemfile))
- Via ONBUILD triggers it installs missing gems and Node modules, then compiles the assets

See [builder/Dockerfile](./builder/Dockerfile)

### Final stage

The `final` stage builds the production image, which includes just the bare minimum.

- Based on [ruby:3.4.4-alpine](https://github.com/docker-library/ruby/blob/master/3.4/alpine3.21/Dockerfile)
- Adds packages needed for production: postgresql-client, tzdata, file
- Via ONBUILD triggers it mainly copies the app and gems from the `builder` stage

See [final/Dockerfile](./final/Dockerfile)

### Staying up-to-date

Using [Dependabot](https://dependabot.com/), every updated Ruby gem results in an updated image.

### How to use for your Rails application

#### Building the Docker image

Add this `Dockerfile` to your application:

```Dockerfile
FROM ghcr.io/ledermann/rails-base-builder:3.4.4-alpine AS builder
FROM ghcr.io/ledermann/rails-base-final:3.4.4-alpine
USER app
# Optional: Enable YJIT
# ENV RUBY_YJIT_ENABLE=1
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
```

Yes, this is the complete `Dockerfile` of your Rails app. It's so simple because the work is done by ONBUILD triggers.

Now build the image:

```bash
$ docker build .
```

#### Building the Docker image with BuildKit

```
docker buildx build .
```

You can use private npm/Yarn packages by mounting the config file:

```
docker buildx build --secret id=npmrc,src=$HOME/.npmrc .
```

or

```
docker buildx build --secret id=yarnrc,src=$HOME/.yarnrc.yml .
```

In a similar way you can provide a configuration file for Bundler:

```
docker buildx build --secret id=bundleconfig,src=$HOME/.bundle/config .
```

#### Continuous integration (CI)

Example to build the application's image with GitHub Actions and push it to the GitHub Container Registry:

```yaml
deploy:
  runs-on: ubuntu-latest

  steps:
    - uses: actions/checkout@v4
      with:
        fetch-depth: 0

    - name: Fetch tag annotations
      # https://github.com/actions/checkout/issues/290
      run: git fetch --tags --force

    - name: Login to GitHub Container Registry
      uses: docker/login-action@v3
      with:
        registry: ghcr.io
        username: ${{ github.repository_owner }}
        password: ${{ secrets.GITHUB_TOKEN }}

    - name: Build the image
      run: |
        export COMMIT_TIME=$(git show -s --format=%cI ${GITHUB_SHA})
        export COMMIT_SHA=${GITHUB_SHA}
        export COMMIT_VERSION=$(git describe)
        export COMMIT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
        docker buildx build --build-arg COMMIT_TIME --build-arg COMMIT_SHA --build-arg COMMIT_VERSION --build-arg COMMIT_BRANCH -t ghcr.io/user/repo:latest .

    - name: Push the image
      run: docker push ghcr.io/user/repo:latest
```

## Available Docker images

Both Docker images (`builder` and `final`) are regularly published at ghcr.io and tagged with the current Ruby version:

- https://github.com/ledermann/docker-rails-base/pkgs/container/rails-base-builder
- https://github.com/ledermann/docker-rails-base/pkgs/container/rails-base-final

Beware: The published images are **not** immutable. When a dependency (e.g. Ruby gem) is updated, the images will be republished using the **same** tag.

When a new Ruby version comes out, a new tag is introduced and the images will be published using this tag and the former images will not be updated anymore. Here is a list of the tags that have been used in this repo so far:

| Ruby version | Tag          | First published |
| ------------ | ------------ | --------------- |
| 3.4.4        | 3.4.4-alpine | 2025-05-16      |
| 3.4.3        | 3.4.3-alpine | 2025-04-15      |
| 3.4.2        | 3.4.2-alpine | 2025-02-16      |
| 3.4.1        | 3.4.1-alpine | 2024-12-28      |
| 3.3.6        | 3.3.6-alpine | 2024-11-06      |
| 3.3.5        | 3.3.5-alpine | 2024-09-05      |
| 3.3.4        | 3.3.4-alpine | 2024-07-10      |
| 3.3.3        | 3.3.3-alpine | 2024-06-13      |
| 3.3.2        | 3.3.2-alpine | 2024-05-31      |
| 3.3.1        | 3.3.1-alpine | 2024-04-23      |
| 3.3.0        | 3.3.0-alpine | 2023-12-27      |
| 3.2.2        | 3.2.2-alpine | 2023-03-31      |
| 3.2.1        | 3.2.1-alpine | 2023-02-10      |
| 3.2.0        | 3.2.0-alpine | 2023-01-13      |
| 3.1.3        | 3.1.3-alpine | 2022-11-26      |
| 3.1.2        | 3.1.2-alpine | 2022-04-13      |
| 3.1.1        | 3.1.1-alpine | 2022-02-19      |
| 3.1.0        | 3.1.0-alpine | 2022-01-08      |
| 3.0.3        | 3.0.3-alpine | 2021-11-24      |
| 3.0.2        | 3.0.2-alpine | 2021-07-08      |
| 3.0.1        | 3.0.1-alpine | 2021-04-06      |
| 3.0.0        | 3.0.0-alpine | 2021-02-15      |
| 2.7.2        | 2.7.2-alpine | 2020-10-10      |
| 2.7.1        | 2.7.1-alpine | 2020-05-20      |
| 2.6.6        | -            | 2020-04-01      |
| 2.6.5        | -            | 2020-01-24      |

The latest Docker images are also tagged as `latest`. However, it is not recommended to use this tag in your Rails application, because updating an app to a new Ruby version usually requires some extra work.

## FAQ

### Why not simply use layer caching?

Docker supports layer caching, so for building images it performs just the needed steps: If there is a layer from a former build and nothing has changed, it will be used. But for dependencies, this means: If a single Ruby gem in the application was updated or added, the step with `bundle install` is run again, so **all** gems will be installed again.

Using a prebuilt image improves installing dependencies a lot, because only the different/updated dependencies will be installed - all existing ones will be reused.

### What if my app requires slightly different dependencies?

This doesn't matter:

- A missing Alpine package can be installed with `apk add` inside your app's Dockerfile.
- A missing Node module (or version) will be installed with `rails assets:precompile` via the ONBUILD trigger.
- A missing Ruby gem (or version) will be installed with `bundle install` via the ONBUILD trigger.

### There are gems included that my app doesn't need. Will they bloat the resulting image?

No. In the build stage there is a `bundle clean --force`, which uninstalls all gems not referenced in the app's Gemfile.

### My app does not need to compile assets (e.g. API only or ImportMaps). Can I use this project?

There is a workaround for this. Just add ths file to define a dummy task:

```ruby
# lib/tasks/precompile.rake
namespace :assets do
  desc 'Precompile assets'
  task precompile: :environment do
    puts 'No need to precompile assets'
  end
end
```

In addition, you need to ensure that these files are present, even if they are not needed:

```
package.json
yarn.lock
.yarnrc.yml
.yarn
```

You can do this by running:

```bash
yarn init
yarn install
touch .yarnrc.yml
mkdir -p .yarn
touch .yarn/.keep
```
