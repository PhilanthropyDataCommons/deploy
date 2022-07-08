#!/bin/bash

# Deploy a version of pdc from a repo based on the contents of a file.
#
# The file can be written by an unprivileged user. The deployment user
# running this script can be a more-privileged user. The file contains
# a tag. The context for which project and file to use is from
# variables in a .env file.
#
# For example, if the file contains "v1", the .env file may contain a
# variable with the url prefix such as "https://pdc/deploy/" and the
# .env also includes a variable with the file name "compose.yml", then
# the compose script to get/copy will be something like the following:
# https://pdc/deploy/v1/compose.yml
#
# After getting the compose script, "down" the old one (if there) and
# "up" the new one.
#
# Following successful processing of the tag file, this script deletes
# it.
#
# Requires docker-compose or docker with the compose plugin.
# Requires a .env file with two variables, see below.

DOCKER_COMPOSE_COMMAND="docker-compose"

if ! command -v $DOCKER_COMPOSE_COMMAND &> /dev/null; then
    DOCKER_COMPOSE_COMMAND='docker compose'
fi

# Test the command by asking for the docker-compose version.
$DOCKER_COMPOSE_COMMAND version || exit 1

# Source some environment variables, ensure they are non-empty.
. .env || exit 2

test ! -z "$REPOSITORY_PREFIX" || exit 3
test ! -z "$REPOSITORY_FILE" || exit 4

# The tag file is expected to contain a tag to release on line 1.
TAG_FILE="${TAG_FILE:-./tag_file}"

# The file at $COMPOSE_NAME_FILE contains the name of the running
# compose file. This is not expected to be present on first run.
COMPOSE_NAME_FILE=./compose_current_file_name

# We use a lock dir because it can be created atomically.
LOCK_DIR=./deployment_in_progress

# If the directory exists, there is another one of these running or a
# failed run that exited before finishing.
mkdir $LOCK_DIR || exit 5

if [[ ! -f $TAG_FILE ]]; then
    echo "No tag file given: no need to deploy, exiting normally."
    rmdir $LOCK_DIR
    exit 0
fi

VERSION=$(head -n 1 $TAG_FILE)
test ! -z "$VERSION" || exit 6

# In the filename, replace slashes with underscores. This way, we can
# test from a branch or other url containing slashes and still have a
# valid filename.
NEW_COMPOSE_FILE=compose-$(echo $VERSION | sed 's/\/\|\\/_/g' ).yml
URL_OF_COMPOSE_FILE=$REPOSITORY_PREFIX/$VERSION/$REPOSITORY_FILE
CURL_STATUS=$(curl -v -L -o $NEW_COMPOSE_FILE $URL_OF_COMPOSE_FILE |& grep "^< HTTP/" | cut -d' ' -f 3)

if test ! -f $NEW_COMPOSE_FILE; then
    echo "Failed to get the compose file from $URL_OF_COMPOSE_FILE"
    echo "HTTP status: $CURL_STATUS"
    exit 7
fi

EXISTING_COMPOSE_FILE=$(head -n 1 $COMPOSE_NAME_FILE)

# Pull new images from the new file before attempting a down or up.
$DOCKER_COMPOSE_COMMAND -f $NEW_COMPOSE_FILE pull || exit 8

# Stop existing software if present, e.g.
# docker-compose -f compose.yml down
if ! test -z "$EXISTING_COMPOSE_FILE"; then
    $DOCKER_COMPOSE_COMMAND -f $EXISTING_COMPOSE_FILE down || exit 9
else
    $DOCKER_COMPOSE_COMMAND -f $NEW_COMPOSE_FILE down || exit 10
fi

# Start new software, e.g.
# docker-compose -f compose.yml up -d
$DOCKER_COMPOSE_COMMAND -f $NEW_COMPOSE_FILE up -d || exit 11
echo $NEW_COMPOSE_FILE > $COMPOSE_NAME_FILE

# Remove the tag file because it has been processed successfully.
rm -f $TAG_FILE
rmdir $LOCK_DIR
