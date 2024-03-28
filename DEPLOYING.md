# Deploying Philanthropy Data Commons software

This document guides one through deployment to production of the back-end
Philanthropy Data Commons software to run at
https://api.philanthropydatacommons.org and
https://auth.philanthropydatacommons.org.

The [data-viewer](https://github.com/PhilanthropyDataCommons/data-viewer/) at
https://pilot.philanthropydatacommons.org has its own separate process.

In brief, the process is to write a version to a file then verify that the
deployment happened successfully.

A Docker Compose YAML
[file](https://github.com/PhilanthropyDataCommons/deploy/blob/main/compose.yml)
is used to deploy. The file includes the PDC service ("web") and other services
upon which PDC depends.

A
[bash script](https://github.com/PhilanthropyDataCommons/deploy/blob/main/deploy.sh)
running under cron on the target host:
 - gets the new compose file,
 - pulls new components (images) using the new compose file,
 - stops the old services (containers) using the old compose file,
 - starts the new services (containers) using the new compose file,
 - and notifies the team via chat message.

To start to deploy and to find exactly what version to deploy, the script
[looks inside a file](https://github.com/PhilanthropyDataCommons/deploy/blob/e0d24b8a19ee563938f8211bca0485a97ff1a6e9/deploy.sh#L90)
currently `~build/deployment/tag_to_deploy`.

This setup supports both automated and manual deployments that have exactly the
same steps with exactly the same code.

## To deploy a newly built version of the PDC service to production

This is the streamlined case. It assumes that both the test and production
machines were already set up with users, directories, Docker, Certbot, scripts,
environment variables, additional Keycloak JAR files, and so forth.

In short, merge software to the main branch of the `service` repository and the
software will be auto-deployed.

### Background

When someone merges code to the main branch in the
[service repository](https://github.com/PhilanthropyDataCommons/service),
[GitHub Actions](https://github.com/PhilanthropyDataCommons/service/tree/main/.github/workflows)
runs tests, builds a new Docker image with the PDC service and its dependencies,
and pushes the new image to 
[service packages](https://github.com/PhilanthropyDataCommons/service/pkgs/container/service)
. The GitHub Actions also tag the new service image with a version, such as
`20230616-00a3cc8`. The tag is on the binary, not the source code, but the
version text is based on the git commit, so that we can always trace the image
back to the source code whence it came.

The
[GitHub Action](https://github.com/PhilanthropyDataCommons/service/blob/cd2e2a4c39d87479f7b145a9163e155ede7676f2/.github/workflows/build.yml#L46)
that builds and pushes an image also triggers an
[Action](https://github.com/PhilanthropyDataCommons/deploy/blob/main/.github/workflows/update-service-image.yml)
in the deploy repository which in turn updates the compose.yml with the
newly created image version of the service, tags the compose.yml with a
version, and
[automatically deploys](https://github.com/PhilanthropyDataCommons/deploy/blob/21ecbd6bf78dc9af3313056486b5339e38b868f1/.github/workflows/trigger-deployments.yml#L28)
PDC software to the test environment using the newly updated and tagged
compose.yml.

If the deployment to the test environment succeeds, the same workflow
[automatically deploys](https://github.com/PhilanthropyDataCommons/deploy/blob/21ecbd6bf78dc9af3313056486b5339e38b868f1/.github/workflows/trigger-deployments.yml#L43)
the exact same PDC software to the production environment.

## How to manually deploy in a way similar to auto-deploy

The rest of this guide assumes you wish to cause a deployment manually.

## Overview of the deployment pipeline from high-level to low-level

- `trigger-deployments.yml`: runs on a CI server when a tag is pushed.
- `trigger_deployment.sh`: called by `trigger-deployments.yml` (on CI server).
- `deploy.sh`: runs on the target host on cron, acts on a version file.
- `docker-compose` (or `docker compose`): called by `deploy.sh` (on host).

It is possible to use any of the above four levels depending on your use case.

### To trigger a normal test-then-production deployment tag a `deploy` commit

If you want the usual `trigger-deployments.yml` script to deploy both to test
and then production, create and push a version tag on the commit to deploy.
The tagged commit must be on the main branch if you want it to go to production.

If you want `trigger-deployments.yml` to deploy to only the test environment but
not production, create a branch, tag a commit on that branch, and push the tag.

If you want to deploy to neither the usual test nor production environment, then
set up docker, environment variables, users, and scripts on the target host and
then run the `deploy.sh` script or run the docker compose script on that host.
