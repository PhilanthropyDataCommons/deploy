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
running under cron:
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
back back to the source code whence it came.

The
[GitHub Action](https://github.com/PhilanthropyDataCommons/service/blob/cd2e2a4c39d87479f7b145a9163e155ede7676f2/.github/workflows/build.yml#L46)
that builds and pushes an image also triggers an
[Action](https://github.com/PhilanthropyDataCommons/deploy/blob/main/.github/workflows/update-service-image.yml)
in the deploy repository which in turn updates the compose.yml with the
newly created image version of the service, tags the compose.yml with a
version, and
[automatically deploys](https://github.com/PhilanthropyDataCommons/deploy/blob/e0d24b8a19ee563938f8211bca0485a97ff1a6e9/.github/workflows/send-tag-to-machine.yml#L22)
PDC software to the test environment using the newly updated and tagged
compose.yml.

The rest of this guide assumes you saw that tests passed and you want to deploy
the recently built and tested version of the PDC service to the production
environment.

### Verify that the deployment to the test environment succeeded

1. Check the
[PDC ci/cd chat](https://chat.opentechstrategies.com/#narrow/stream/75-PDC/topic/ci.2Fcd)
for the most recent message from "PDC Testing Bot" containing the tagged
`compose.yml` file, e.g. "Deployment of https://.../20230613-e0d24b8/compose.yml
succeeded." Success here means the deploy script exited 0 which means the Docker
Compose commands succeeded.
2. Check the
[back-end service docs in the test environment](https://api-test.philanthropydatacommons.org)
. If the swagger docs show up, this means the reverse-proxy container (nginx)
and web container (Node.js) are running.
3. Check the
[auth service in the test environment](https://auth-test.philanthropydatacommons.org/realms/pdc)
. If a JSON doc shows up, this means the reverse-proxy container (nginx), auth
container (Keycloak), and database container (PostgreSQL) are running.

### Check for active sessions in production

Visit
[PDC sessions in Keycloak](https://auth.philanthropydatacommons.org/admin/master/console/#/pdc/sessions)
.

If there are non-PDC-team users active, wait until there is a comfortable amount
of time since last activity, e.g. 30 mins.

### Copy the Docker Compose file version to your clipboard

The version ID can be found in the
[deploy project's tags](https://github.com/PhilanthropyDataCommons/deploy/tags)
or in the url in the chat message from the "PDC Testing Bot" above. In the
example above the version is `20230613-e0d24b8`.

### Tell the deploy script the version of the Docker Compose file to deploy

These are the commands that actually deploy the software.

 - `ssh $OTS_USERNAME@api.philanthropydatacommons.org`

In the next command, replace VERSION with the compose file version:

 - `echo "VERSION" | sudo -u build tee ~build/deployment/tag_to_deploy`
 - `exit`

### Verify that the deployment to the production environment succeeded

(Continuing the above session at `api.philanthropydatacommons.org` as
`$OTS_USERNAME`):
 - `sudo docker ps`

Repeat this command every few seconds until you see the old containers go down
and new containers come up. When all containers are up (presently four), this
means the deployment should be successful. To be extra sure one can also repeat
the same steps from the test environment above, i.e.:

1. Check https://chat.opentechstrategies.com/#narrow/stream/75-PDC/topic/ci.2Fcd
for the most recent message from "PDC Production Bot".
2. Check https://api.philanthropydatacommons.org
3. Check https://auth.philanthropydatacommons.org/realms/pdc
4. For good measure, check https://pilot.philanthropydatacommons.org to verify
it reaches the back-end service.
