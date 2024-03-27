#!/bin/bash

set -e

# Trigger a deployment of a version of PDC by writing a version file.
#
# Unlike `deploy.sh`, which runs on the target environment host, this
# script runs on the continuous integration (CI) server, viz. GitHub
# during GitHub actions/workflows.
#
# The design follows a goal in Continuous Delivery (2012): to be able
# to name a version of the software to deploy and the environment into
# which to deploy. The "environment" here is found in a handful of,
# you guessed it, environment variables. In the GitHub repo settings,
# different environments are set up with different values for these
# variables. More concretely, see the following URL:
# https://github.com/PhilanthropyDataCommons/deploy/settings/environments
#
# The first four environment variables help make a successful SSH
# connection via public key authentication.
#
# These two are the continuous integration server's SSH keypair:
# `BUILD_SSH_PRIVATE_KEY` and `BUILD_SSH_PUBLIC_KEY`.
#
# `MACHINE_ADDRESS`: the IP address of the host into which to deploy.
# `KNOWN_HOSTS`: the public key of the host into which to deploy
#
# For more on OpenSSH's public key authentication (used by `scp`), see
# https://man.openbsd.org/ssh#i and also
# https://man.openbsd.org/ssh_config.5#UserKnownHostsFile
#
# `DEPLOYED_VERSION_URL`: a web URL serving the successfully deployed
# current version string of the running software post-deployment. This
# is used as a high-level ("smoke") test that the expected software is
# deployed, up, running, etc. The `deploy.sh` on the host writes this
# after successful deployment and the reverse proxy server serves it.
# If the returned plain text HTTP body matches the version we expected
# to deploy, we can have confidence that deployment succeeded. The key
# reason to do this is to programmatically verify that a deployment to
# the test environment succeeded before deploying to a production
# environment. It is also nice to have the CI server report back that
# the deployment to the production environment succeeded or failed.
# The URL is polled by the action, not this script.
#
# Not environment-specific is the software version, `TAG_TO_DEPLOY`.
# It is called a tag here because creating a `git` tag in this repo
# is the mechanism that triggers this process. The `deploy.sh` script
# will find the software using the repository and this tag.

test ! -z "${BUILD_SSH_PRIVATE_KEY}" || exit 2
test ! -z "${BUILD_SSH_PUBLIC_KEY}" || exit 3
test ! -z "${KNOWN_HOSTS}" || exit 4
test ! -z "${MACHINE_ADDRESS}" || exit 5
test ! -z "${TAG_TO_DEPLOY}" || exit 6

# A tag is used to create a software version. The tag can be pushed
# manually or automatically. We assume the tag is in `TAG_TO_DEPLOY`.
echo "${TAG_TO_DEPLOY}" > ~/tag_to_deploy
chmod 660 ~/tag_to_deploy

# Set up SSH. The host needs the build user to have added the CI
# server's public key to `authorized_hosts`.
touch ~/ssh_id
chmod 700 ~/ssh_id
echo "${BUILD_SSH_PRIVATE_KEY}" > ~/ssh_id
echo "${BUILD_SSH_PUBLIC_KEY}" > ~/ssh_id.pub
touch ~/my_known_hosts
chmod 700 ~/my_known_hosts
echo "${KNOWN_HOSTS}" > ~/my_known_hosts

# Set the version to deploy. The `deploy.sh` script will pick this up.
scp -v -i ~/ssh_id -o UserKnownHostsFile=~/my_known_hosts -p ~/tag_to_deploy "build@${MACHINE_ADDRESS}:/home/build/deployment/tag_to_deploy"
