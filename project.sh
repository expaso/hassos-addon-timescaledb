#!/bin/bash
set -e;

PLATFORM="linux/arm64"

function printInColor() {
    # Set the color code based on the color name
    color=0
    case $2 in
        "red")    color=31;;
        "green")  color=32;;
        "yellow") color=33;;
        "blue")   color=34;;
        "purple") color=35;;
        "cyan")   color=36;;
        "white")  color=37;;
    esac

    # Set the background color code based on the color name
    background=0
    case $3 in
        "red")    background=41;;
        "green")  background=42;;
        "yellow") background=43;;
        "blue")   background=44;;
        "purple") background=45;;
        "cyan")   background=46;;
        "white")  background=47;;
    esac

    # Print the message in the given color, then reset the color
    echo -e "\e[${background}m\e[${color}m$1\e[0m"
}

function build_dependency() {
    local component=$1
    local version=$2

    printInColor "Building docker dependency ${component}" "green"

    docker buildx build \
        --push \
        --platform linux/amd64,linux/arm64,linux/arm/v7,linux/i386,linux/arm/v6 \
        --cache-from type=registry,ref=husselhans/hassos-addon-timescaledb-${component}:cache \
        --cache-to type=registry,ref=husselhans/hassos-addon-timescaledb-${component}:cache,mode=max \
        --tag husselhans/hassos-addon-timescaledb-${component}:${version} \
        --progress plain \
        --build-arg "VERSION=${version}" \
        --file ./timescaledb/docker-dependencies/${component} \
        . \
        && printInColor "Done building docker image!" "green"    
}

function build() {
    local output=$1

    printInColor "Building docker image.."

    # Build the image conform the instructions
    # Push the dev image to docker hub
    # build the image
    docker buildx build \
        --platform ${PLATFORM} \
        --cache-from type=registry,ref=husselhans/hassos-addon-timescaledb:cache \
        --tag husselhans/hassos-addon-timescaledb-aarch64:dev \
        --build-arg BUILD_FROM=ghcr.io/hassio-addons/base/aarch64:15.0.7 \
        --progress plain \
        --build-arg CACHE_BUST=$(date +%s) \
        --output ${output} \
        ./timescaledb \
        && printInColor "Done building docker image!" "green"

    #Stop when an error occured
    if [ $? -ne 0 ]; then
        printInColor "Error building docker image!" "red"
        exit 1
    fi
}

function run_hassos() {
    # Run the docker image on hassos
    printInColor "Pulling and restaring on HASOS.. "

    # # Copy the docker image to hassos
    # printInColor "Pulling docker image on hassos.." "yellow"
    # # run the docker image pull command remote on Hassos
    ssh -i ~/.ssh/hassos -l root -p 22222 homeassistant "docker image pull husselhans/hassos-addon-timescaledb-aarch64:dev \
        && ha addons stop  local_timescaledb  \
        && ha addons start local_timescaledb"
    printInColor "Done pulling docker image on hassos!" "green"
}

function run_local() {
    printInColor "Starting standalone docker image "

    # Run the docker image locally
    mkdir -p /tmp/timescale_data
    docker run --rm --name timescaledb --platform ${PLATFORM} -v /tmp/timescale_data:/data -p 5432:5432 husselhans/hassos-addon-timescaledb-aarch64:dev  
}

function inspect() {
    printInColor "Starting standalone docker image shell"

    # Run the docker image locally
    mkdir -p /tmp/timescale_data
    docker run --entrypoint "/bin/ash" -it --rm --name timescaledb --platform ${PLATFORM} -v /tmp/timescale_data:/data -p 5432:5432 husselhans/hassos-addon-timescaledb-aarch64:dev
}

function build_ha() {
    local tag=$1
    printInColor "Building all platforms for Home Assistant with tag ${tag}"
    #docker login
    docker run \
        --rm \
        --privileged \
        -v ~/.docker:/root/.docker \
        -v /var/run/docker.sock:/var/run/docker.sock:ro \
        -v ${PWD}/timescaledb:/data \
        homeassistant/amd64-builder \
        --target timescaledb \
        --all \
        -v latest \
        -t /data \
        --docker-user husselhans \
        --docker-password ***REMOVED***
}

if [ "$1" == "build" ]; then
    build "type=registry,push=true"
    exit 0
elif [ "$1" == "build-dependencies" ]; then
    #build_dependency timescaledb-tools "latest"
    #build_dependency pgagent-pg16 "4.2.2"
    build_dependency timescaledb-toolkit-pg16 "1.18.0"
    #build_dependency postgis-pg15 "3.3.3"
    exit 0
elif [ "$1" == "build-ha" ]; then
    build_ha latest
    exit 0
elif [ "$1" == "run-hassos" ]; then
    build "type=registry,push=true"
    run_hassos
    exit 0
elif [ "$1" == "debug" ]; then
    build type=docker
    run_local
    exit 0
elif [ "$1" == "inspect" ]; then
    build type=docker
    inspect
    exit 0
else
    printInColor "Unknown command!" "red"
    exit 1
fi
