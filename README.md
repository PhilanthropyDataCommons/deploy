# Deployment scripts for Philanthropy Data Commons service

These are tools that help deploy the PDC. They are separate from the PDC
component repositories because they operate above a source-code level, are
optional, and they can work with multiple PDC services above any given PDC
service's level.

## compose.yml

The `compose.yml` is the thing to be deployed. It contains declarations or
configuration of binaries, environment variables, and so forth: everything
needed to run the full application on a single machine. Strictly speaking,
everything but `docker` and `docker-compose` (or the `compose` plugin for
`docker`). Passing a `compose.yml` to `docker-compose -f compose.yml up -d`
will start the PDC applications and their dependencies. This operates at a
binary level (as opposed to source code level) and supports GNU/Linux amd64
machines, also known as `platform=linux/amd64` in Docker parlance.

The `compose.yml` uses environment variables from a `.env` file.

## deploy.sh

The `deploy.sh` script runs `docker-compose down` and `docker-compose up` when
it finds a `TAG_FILE` environment variable that points to a present file. It can
run on demand, manually, or on a timer (e.g. cron). If there is a Zulip chat API
key present in `ZULIP_BOT_API_KEY`, it will also send a message to the
configured chat stream and topic configured in corresponding `ZULIP_...`
variables. See `.env.example` for examples. The version of the `compose.yml`
file that it deploys is `REPOSITORY_PREFIX` followed by slash, followed by the
contents of the `TAG_FILE`, followed by the `REPOSITORY_FILE`, for example:

    https://raw.githubusercontent.com/PhilanthropyDataCommons/deploy/20220715-5273364/compose.yml

The exact thing deployed is under version control. The exact images used for
each service or application underneath it should be included, giving the best
chance to deterministically reproduce issues.

The `deploy.sh` gets sent to the machines manually rather than automatically.

The `deploy.sh` uses environment variables from a `.env` file.

## Other components

See examples of:

 * An nginx configuration in `proxy.conf.example`
 * Environment variables in `.env.example`

To use either of these, copy them to the same name without `.example`.

## Other considerations

Because the `docker` commands (with vanilla Docker) essentially grant root
access to machines, this is the reason to separate out the user that writes a
tag name to a file and the user that runs `deploy.sh`. A GitHub action pushes to
the `TAG_FILE` location expected by the `deploy.sh` script, but the push happens
with a less-privileged user, while the execution of `deploy.sh` happens with a
user able to run the docker commands.

## Logs

Use the usual `docker ps` command to see which containers are running and the
`docker logs {container_id}` to see logs for a given container.
