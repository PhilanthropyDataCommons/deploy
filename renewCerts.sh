#!/bin/bash

# A script to renew certificates with certbot and send chat message with result

# Example usage, expected within crontab:
# 0 18 * * SUN /root/renewCerts.sh

# Requirements:
# certbot (installed on the host, not in a container),
# nginx already configured to point to letsencrypt certificates, and
# Environment variables in /home/deploy/.env:
# - REVERSE_PROXY_CONTAINER_GROUP
# - WEB_SERVER_HOSTNAME
# - ZULIP_BASE_URL
# - ZULIP_BOT_EMAIL_ADDRESS
# - ZULIP_BOT_API_KEY
# - ZULIP_STREAM
# - ZULIP_TOPIC

set -eo pipefail

test -x "$(which certbot)"
# Instead of sourcing /home/deploy/.env verbatim, source only strictly formed and used env vars.
. <(egrep '^(WEB_SERVER_HOSTNAME|REVERSE_PROXY_CONTAINER_GROUP|ZULIP_BASE_URL|ZULIP_BOT_EMAIL_ADDRESS|ZULIP_BOT_API_KEY|ZULIP_STREAM|ZULIP_TOPIC)=[a-zA-Z0-9"\/\:\.\@\_\-]+$' /home/deploy/.env)
test ! -z "$WEB_SERVER_HOSTNAME"
test ! -z "$REVERSE_PROXY_CONTAINER_GROUP"
test ! -z "$ZULIP_BASE_URL"
test ! -z "$ZULIP_BOT_EMAIL_ADDRESS"
test ! -z "$ZULIP_BOT_API_KEY"
test ! -z "$ZULIP_STREAM"
test ! -z "$ZULIP_TOPIC"

set +eo pipefail

function fin() {
    # Exit. Also notify of the result via chat if an API key is present.
    exit_code=0
    error_message=$1
    message="✅ Certificate renewals (or checks) for https://${WEB_SERVER_HOSTNAME} succeeded."

    if test ! -z "$error_message"; then
        exit_code=1
        message="❌ Certificate renewals (or checks) for https://${WEB_SERVER_HOSTNAME} FAILED: ${error_message}"
    fi

    curl -X POST ${ZULIP_BASE_URL}/api/v1/messages \
        -u ${ZULIP_BOT_EMAIL_ADDRESS}:${ZULIP_BOT_API_KEY} \
        --data-urlencode type=stream \
        --data-urlencode to=${ZULIP_STREAM} \
        --data-urlencode topic=${ZULIP_TOPIC} \
        --data-urlencode "content=${message}"

    exit $exit_code
}

certbot certonly -n --domain=$WEB_SERVER_HOSTNAME --standalone --keep-until-expiring \
    || fin $(tail -n 10 /var/log/letsencrypt/letsencrypt.log)
# Make sure the reverse proxy user has read/execute privileges on the cert and key files.
chgrp -R $REVERSE_PROXY_CONTAINER_GROUP /etc/letsencrypt/{live,archive} \
    || fin "Failed to chgrp /etc/letsencrypt/{live,archive} to $REVERSE_PROXY_CONTAINER_GROUP"
chmod -R g+rx /etc/letsencrypt/{live,archive} \
    || fin "Failed to add group read and execute permissions to /etc/letsencrypt/{live,archive}"
# For unknown reasons, sending the reload signal to the nginx process inside the
# container fails to have nginx pick up new certificates. Instead, do a full
# container restart. See issue
# https://github.com/PhilanthropyDataCommons/deploy/issues/90. This can likely
# break active connections but shouldn't lose sessions.
docker restart deploy_reverse-proxy_1 \
    || fin "Failed to restart to reverse proxy container"
(( $(docker ps | grep reverse-proxy | wc -l) == "1" )) \
    || fin "The reverse-proxy container is no longer running"

fin
