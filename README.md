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


# Requirements

This repo is based on the following assumptions:

- Your Docker host is compatible with [Alpine Linux 3.14](https://wiki.alpinelinux.org/wiki/Release_Notes_for_Alpine_3.14.0), which requires Docker 20.10.0 or later
- Your app is compatible with [Ruby 3.0.2 for Alpine Linux](https://github.com/docker-library/ruby/blob/master/3.0/alpine3.14/Dockerfile)
- Your app uses Ruby on Rails 6.0 or 6.1
- Your app uses PostgreSQL
- Your app installs Node modules with [Yarn](https://yarnpkg.com/)
- Your app compiles JS with [Webpacker](https://github.com/rails/webpacker) and/or [Asset pipeline (Sprockets)](https://github.com/rails/sprockets-rails)

If your project differs from this, I suggest to fork this project and create your own base image.


## How?

It uses [multi-stage building](https://docs.docker.com/develop/develop-images/multistage-build/) to build a very small production image. There are two Dockerfiles in this repo, one for the first stage (called `Builder`) and one for the resulting stage (called `Final`).

### Builder stage

The `Builder` stage installs Ruby gems and Node modules. It also includes Git, Node.js and some build tools - all we need to compile assets.

- Based on [ruby:3.0.2-alpine](https://github.com/docker-library/ruby/blob/master/3.0/alpine3.14/Dockerfile)
- Adds packages needed for installing gems and compiling assets: Git, Node.js, Yarn, PostgreSQL client and build tools
- Adds some standard Ruby gems (Rails 6.1 etc., see [Gemfile](./Builder/Gemfile))
- Adds Node modules from the Rails community (Turbo, Stimulus etc., see [package.json](./Builder/package.json))
- Via ONBUILD triggers it installs missing gems and Node modules, then compiles the assets

See [Builder/Dockerfile](./Builder/Dockerfile)


### Final stage

The `Final` stage builds the production image, which includes just the bare minimum.

- Based on [ruby:3.0.2-alpine](https://github.com/docker-library/ruby/blob/master/3.0/alpine3.14/Dockerfile)
- Adds packages needed for production: postgresql-client, tzdata, file
- Via ONBUILD triggers it mainly copies the app and gems from the `Builder` stage

See [Final/Dockerfile](./Final/Dockerfile)


### Staying up-to-date

Using [Dependabot](https://dependabot.com/), every updated Ruby gem or Node module results in an updated image.


### How to use for your Rails application

#### Building the Docker image

Add this `Dockerfile` to your application:

```Dockerfile
FROM ledermann/rails-base-builder:3.0.2-alpine AS Builder
FROM ledermann/rails-base-final:3.0.2-alpine
USER app
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
```

Yes, this is the complete `Dockerfile` of your Rails app. It's so simple because the work is done by ONBUILD triggers.

Now build the image:

```bash
$ docker build .
```

#### Building the Docker image with BuildKit

[BuildKit](https://docs.docker.com/develop/develop-images/build_enhancements/) requires a little [workaround](https://github.com/moby/buildkit/issues/816) to trigger the ONBUILD statements. Add a `COPY` statement to the `Dockerfile`:

```Dockerfile
FROM ledermann/rails-base-builder:3.0.2-alpine AS Builder
FROM ledermann/rails-base-final:3.0.2-alpine

# Workaround to trigger Builder's ONBUILDs to finish:
COPY --from=Builder /etc/alpine-release /tmp/dummy

USER app
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
```

Now you can build the image with BuildKit:

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


#### Continuous integration (CI)

Example to build the application's image with GitHub Actions and push it to the GitHub Container Registry:

```yaml
deploy:
  runs-on: ubuntu-latest

  steps:
    - uses: actions/checkout@v2

    - name: Login to GitHub Container Registry
      run: echo ${{ secrets.CR_PAT }} | docker login ghcr.io -u $GITHUB_ACTOR --password-stdin

    - name: Build the image
      run: |
        export COMMIT_TIME=$(git show -s --format=%ci ${GITHUB_SHA})
        export COMMIT_SHA=${GITHUB_SHA}
        docker build --build-arg COMMIT_TIME --build-arg COMMIT_SHA -t ghcr.io/user/repo:latest .

    - name: Push the image
      run: docker push ghcr.io/user/repo:latest
```

## Available Docker images

Both Docker images (`Builder` and `Final`) are regularly published at DockerHub and tagged with the current Ruby version:

* https://hub.docker.com/r/ledermann/rails-base-builder/tags
* https://hub.docker.com/r/ledermann/rails-base-final/tags

Beware: The published images are **not** immutable. When a dependency (e.g. Ruby gem) is updated, the images will be republished using the **same** tag.

When a new Ruby version comes out, a new tag is introduced and the images will be published using this tag and the former images will not be updated anymore. Here is a list of the tags that have been used in this repo so far:

| Ruby version | Tag          | First published |
|--------------|--------------|-----------------|
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
