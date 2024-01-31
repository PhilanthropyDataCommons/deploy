# Deployment scripts for Philanthropy Data Commons service

This project is related to
[Philanthropy Data Commons](https://philanthropydatacommons.org) (PDC). Please
visit https://philanthropydatacommons.org for an overview of PDC.

These are tools that help deploy the PDC. They are separate from the PDC
component repositories because they operate above a source-code level, are
optional, and they can work with multiple PDC services above any given PDC
service's level.

This README describes components of a deployment pipeline. For specific steps to
deploy or upgrade using the existing production deployment pipeline, see
[DEPLOYING](./DEPLOYING.md) and [UPGRADING](./UPGRADING.md).

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

## keycloakInitDb.sh

The `keycloakInitDb.sh` can be used to initialize a postgres database for the
keycloak data. Bitnami scripts run it once on startup then leave a dotfile
named `.user_scripts_initialized` in the same directory to avoid future runs. If
you are using bitnami images locally (no longer shown in the `compose.yml` here)
you need to re-initialize the keycloak database, delete (or move) the database
but also delete the file (e.g. `/home/deploy/.user_scripts_initialized`) so that
the `keycloakInitDb.sh` script will run again on startup.

We used to run Keycloak here using Docker Compose but now it is on its own host.
See the version history for how to set it up in Docker Compose or use the docs
for Keycloak to set up a local Keycloak instance.

## Other components

See examples of:

 * An nginx configuration in `proxy.conf.example`
 * A Keycloak-specific nginx configuration in `keycloak_proxy.conf.example`
 * Environment variables in `.env.example`

To use either of these, copy them to the same name without `.example`.

Make sure there is a `conf/conf.d` directory under the database directory:

    mkdir -p /path/to/PG_DATA/conf/conf.d

This directory can contain additional postgresql settings in `*.conf` files.

Copy `auth_root_page.html` to `/home/reverse-proxy/` or wherever your Keycloak's
nginx instance expects to find it.

## SMS messages for two-factor authentication

Build a Twilio SMS Keycloak provider jar from `./twilio-keycloak-provider` in:
https://github.com/PhilanthropyDataCommons/auth
Add to the providers directory in Keycloak.

Build the keycloak requiredaction jar from `./requiredaction` in:
https://github.com/PhilanthropyDataCommons/auth/tree/main/keycloak-required-action
Add to the providers directory in Keycloak.

More details can be found in the [auth/twilio-keycloak-provider README](
https://github.com/PhilanthropyDataCommons/auth/tree/main/twilio-keycloak-provider
).

Because neither of these jars is published to a central repository, a precompiled
version of each is included in the lib directory in this repository.

## Custom theme for login

Build a PDC Keycloak theme jar from `./pdc-keycloak-theme` in:
https://github.com/PhilanthropyDataCommons/auth
Add to the providers directory in Keycloak.

## Other considerations

Because the `docker` commands (with vanilla Docker) essentially grant root
access to machines, this is the reason to separate out the user that writes a
tag name to a file and the user that runs `deploy.sh`. A GitHub action pushes to
the `TAG_FILE` location expected by the `deploy.sh` script, but the push happens
with a less-privileged user, while the execution of `deploy.sh` happens with a
user able to run the docker commands.

## Logs

Use the usual `docker ps` command to see which containers are running and the
`docker logs {container_id}` to see logs for a given container. Also, logs may
be found via `journalctl` with the `CONTAINER_NAME` as a filter, for example:
`journalctl CONTAINER_NAME=deploy_database_1 --no-pager --utc`.

## TLS configuration with letsencrypt client using docker

Given the included configuration examples, one can run the letsencrypt client
in standalone mode and then copy the certificates to the configured key and
certificate locations.

For example, to create and save the letsencrypt state in the reverse-proxy home:

    sudo docker run -ti --rm -p 80:80 \
        -v "/home/reverse-proxy/letsencrypt:/etc/letsencrypt" \
        -v "/home/reverse-proxy/letsencrypt:/var/lib/letsencrypt" \
        certbot/certbot:v1.32.2 certonly

Repeat the above step for both the auth service and web service domain names.
Then copy the keys and certificates:

    export WEB_DOMAIN=my_domain_hosting_the_back-end_web_service
    sudo cp /home/reverse-proxy/letsencrypt/live/${WEB_DOMAIN}/fullchain.pem \
        /home/reverse-proxy/web-cert.pem
    sudo cp /home/reverse-proxy/letsencrypt/live/${WEB_DOMAIN}/privkey.pem \
        /home/reverse-proxy/web-key.pem

Reload or restart the reverse proxy container to use the certificate:

    sudo docker restart deploy_reverse-proxy_1

## TLS configuration with letsencrypt client on host

A preferred alternative to the above setup is to run letsencrypt on the host.
An example script can be found at `renewCerts.sh`. In this case, one points
the `WEB_CERT`, `WEB_KEY`, directly to the
`/etc/letsencrypt` paths. The compose script already expects `/etc/letsencrypt`
so it is a good idea to run letsencrypt manually before launch.
