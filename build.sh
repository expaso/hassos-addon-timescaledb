#!/bin/bash


# The following section is a helper function that prints the given message in a given color given a foreground color and an optional background color
# Usage: printInColor "message" "color" "background color"
# Example: printInColor "Hello World" "red" "blue"
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

printInColor "Building docker image.."

# Build the image conform the instructions
# Push the dev image to docker hub
docker build --platform linux/aarch64 --tag husselhans/hassos-addon-timescaledb-aarch64:dev ./timescaledb \
&& docker image push husselhans/hassos-addon-timescaledb-aarch64:dev \
&& printInColor "Done building docker image!" "green"

#Stop when an error occured
if [ $? -ne 0 ]; then
    printInColor "Error building docker image!" "red"
    exit 1
fi

# Run the docker image on hassos

# Copy the docker image to hassos
printInColor "Pulling docker image on hassos.." "yellow"
# run the docker image pull command remote on Hassos
ssh -i ~/.ssh/hassos -l root -p 22222 homeassistant "docker image pull husselhans/hassos-addon-timescaledb-aarch64:dev \
    && ha addons stop  local_timescaledb  \
    && ha addons start local_timescaledb"
printInColor "Done pulling docker image on hassos!" "green"


