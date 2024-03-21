# Local development

## The easy way

Run `./project.sh` in the root of the project to build / debug / run the addon during development.

Here are the commands explained:

- `build` build the addon for the current architecture (see PLATFORM in the file) tag it as `dev` and push to docker hub.

- `build-ha` Use the home-assistant builder to build all architechtures and push them to docker hub with the tag `latest`.

- `run-hassos` build the addon for the current architecture (see PLATFORM in the file) tag it as `dev`, puish it to docker hub, SSH login to home-assistant, and pull the image.

- `inspect` build the addon for the current architecture (see PLATFORM in the file) tag it as `dev`, and run it locally with an interactive shell (/bin/ash).

- `debug` build the addon for the current architecture (see PLATFORM in the file) tag it as `dev`, and run it locally with normal starup (not interactive).

## The manual way

To build the lastest version using local docker, switch to the folder where the `dockerfile` resides, and run:

```
docker build --platform linux/aarch64 --tag husselhans/hassos-addon-timescaledb-aarch64:dev .
```
The dockerfile already contains the default build architecture and the default base image:

```
ARG BUILD_FROM=ghcr.io/hassio-addons/base/aarch64:14.0.2
ARG BUILD_ARCH=aarch64
```

Hereafter, you can push the image to dockerhub using cmd of docker desktop for testing purposes.


## Build using Home Asssitant Builder (https://github.com/home-assistant/builder)

To build the latest version using the HomeAssistant Addon Builder container, for `aarch64 architecture` for example, run:

```
docker run --rm --privileged -v ~/.docker:/root/.docker -v ~/hassos-addon-timescaledb/timescaledb:/data homeassistant/amd64-builder -v /var/run/docker.sock:/var/run/docker.sock:ro --target timescaledb --aarch64 -t /data
```

To use it with codenotary CAS signing:

```
docker run --rm --privileged --env CAS_API_KEY=$CAS_API_KEY -v ~/.docker:/root/.docker -v /var/run/docker.sock:/var/run/docker.sock:ro -v ~/hassos-addon-timescaledb/timescaledb:/data homeassistant/amd64-builder --target timescaledb --aarch64 -t /data
```

This will use the base images from the `build.yaml` file, and the architecture specified. Use `--all` instead of `--aarch64`  to build all architectures within the `config.yaml`for example.

## Push latest DEV image to repository

docker image push husselhans/hassos-addon-timescaledb-aarch64:dev

## Pull latest DEV image into your raspoberry pi

SSH  to a home assistant: `ssh -i hassos -l root -p 22222 10.50.1.104`
From a system SSH (port 22222):

```
docker image pull husselhans/hassos-addon-timescaledb-aarch64:dev
```

## Run the addon with an interactive shell

From a system SSH (port 22222), run the docker container with data attached:

```
docker run -it --entrypoint "/bin/sh" -v /mnt/data/supervisor/addons/data/local_timescaledb/:/data:rw  husselhans/hassos-addon-timescaledb-aarch64:dev
```

## For simple DEV inspection, run the container with a shell

```
docker run -it --entrypoint "/bin/sh" husselhans/hassos-addon-timescaledb-aarch64:dev
```

## OR attach to a running container

```
docker exec -it addon_local_timescaledb bash
```