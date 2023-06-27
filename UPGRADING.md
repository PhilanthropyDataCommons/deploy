# Upgrading Philanthropy Data Commons dependencies

This document guides one through upgrades to production back-end services at
https://api.philanthropydatacommons.org and
https://auth.philanthropydatacommons.org.

The [data-viewer](https://github.com/PhilanthropyDataCommons/data-viewer) at
https://pilot.philanthropydatacommons.org has its own separate process.

This applies to the non-PDC-web-container services. As of this writing that is
the auth, database, and reverse-proxy services. The rest is either in the PDC
web service, such as Node.js dependencies managed in the
[service project](https://github.com/PhilanthropyDataCommons/service/blob/main/package.json)
, or on the host, such as cert-bot.

See the summary in [DEPLOYING](./DEPLOYING.md) regarding how software gets
deployed. The same deployment steps apply to the upgrades described here.

In general, try it on a local development environment first, then make sure it
succeeds in the test environment, then finally do it in production.

## Upgrade PostgreSQL (minor version)

Caution: do not use "latest". That won't work the way we want. Also do not use a
less-specific version such as 14-debian-11 or 14.8.0 but only the most specific
image versions such as 14.8.0-debian-11-r14. The purpose of using Bitnami images
is they offer specific tags that only have one image associated. This means we
can deploy exactly the images we tested to production, can pull the same images
when reproducing production issues in a local development environment, and more.

0. Clone or pull [the repo](https://github.com/PhilanthropyDataCommons/deploy).
1. In your local clone of the repo, open the `compose.yml` file.
2. Look at the current version of the `database` image under "database: image:".
3. Visit
[bitnami/postgresql images](https://hub.docker.com/r/bitnami/postgresql/tags).
4. Find the most recent and highest version of the major version of PostgreSQL.
For example, if using PostgreSQL 14, it might be 14.8.0-debian-11-r14.
5. Replace the version in the `compose.yml` file and save the file.
6. Test the pull locally with that compose.yml:
  - `docker compose -f compose.yml pull` (Some systems: `docker-compose`).
If the pull succeeded, continue, otherwise re-check the previous couple steps.
7. Create a pull request to merge the change to main.
8. After merge to main, create a tag on the commit that has your changes.
The tag will be the date in UTC of the commit (in main) followed by the first
seven digits of the git commit hash. For example, if the commit was like this:
`e0d24b8a19ee563938f8211bca0485a97ff1a6e9...Tue Jun 13 19:00:38 2023 +0000`, the
tag would be `20230613-e0d24b8`.
  - `git log --graph --decorate --all` (To find the right commit on main)
  - `git tag [version] [commit]`
  - `git log --graph --decorate --all` (To double-check correct tag happened)
  - `git push origin [tag]` (The [tag] here is the same as the [version] above)
There is an
[opportunity](https://github.com/PhilanthropyDataCommons/deploy/issues/31)
to automate this step as it has been automated for service image deployments.
9. Deploy the newly tagged compose script as usual, start in the `deploying.md`
section titled "Verify that the deployment to the test environment succeeded."

## Upgrade Keycloak (minor version)

The steps are the same as PostgreSQL above, except look for the Keycloak image
at [Docker Hub](https://hub.docker.com/r/bitnami/keycloak/tags) and replace the
version under "auth: image:".

## Upgrade nginx (minor version)

The steps are the same as PostgreSQL and Keycloak above, except look for the
Bitnami nginx image at
[Docker Hub](https://hub.docker.com/r/bitnami/nginx/tags) and replace the
version under "reverse-proxy: image:".

## Upgrade PostgreSQL (major version)

A major PostgreSQL version upgrade is quite a bit more involved than changing a
line in a file and tagging it. There are multiple ways to do it. See the related
[official PostgreSQL docs](https://www.postgresql.org/docs/current/upgrading.html).

### The `pg_dumpall` and `pg_restore` way

This is probably the best way.

See the related
[PostgreSQL docs](https://www.postgresql.org/docs/current/upgrading.html#UPGRADING-VIA-PGDUMPALL)
.

### The `pg_upgrade` way

While this way is not preferred, the steps are elaborated below. Once the steps
for the `pg_dumpall` and `pg_restore` have been elaborated, this section can be
ignored or removed.

Official PostgreSQL documentation mentions
[pg_upgrade](https://www.postgresql.org/docs/current/pgupgrade.html). The
`pg_upgrade` tool requires the binaries of the old version and old configuration
directory in order to perform a migration of the old data format to the new data
format.

To provide access to the binaries of the old PostgreSQL image in the new image,
copy them from the image to a new directory and mount it in the new image.

Be careful not to start PostgreSQL using the Bitnami image until after upgrade.

In a shell with the old PostgreSQL database running:

- `sudo docker exec -ti deploy-database-1 /bin/bash`

Copy the old binaries to a specific old binaries dir (e.g. 14):

- `mkdir /bitnami/postgresql/pg14bin`
- `cp -r /opt/bitnami/postgresql/bin/* /bitnami/postgresql/pg14bin/`

Stop the old PostgreSQL database:

- `pg_ctl stop -D /bitnami/postgresql/data`

This will kick you out of the container because it is now dead.

Now run a container from the old image, with env vars, e.g.

- `sudo docker compose -f compose-[version].yml run -ti database /bin/bash`

Move the old data from old directory to a new specific old directory:

- `mv /opt/bitnami/postgresql/data /bitnami/postgresql/data.old`

Copy the old postgresql.conf, pg_hba.conf, and conf.d contents to the old data
directory and exit the container:

- `cp /opt/bitnami/postgresql/conf/*.conf /bitnami/postgresql/data.old/`
- `cp -r /bitnami/postgresql/conf.d /bitnami/postgresql/data.old/`
- `exit`

Create a new directory for the new PostgreSQL data.
Now we need to init db but without the `pdc` user, only the `postgres` user.
In a shell in the container running the new PostgreSQL, with volumes mounted to
the same locations as the old, initialize the new database:

- `initdb -U postgres data.new`

Perform the upgrade:

- `cd /bitnami/postgresql`
- `pg_upgrade -U postgres --old-datadir /bitnami/postgresql/data.old --new-datadir /bitnami/potsgresql/data.new --old-bindir /bitnami/postgresql/pg14bin --new-bindir /opt/bitnami/postgresql/bin`

### The replication way

If minimal downtime becomes important the replication way may become helpful.

See the related
[PostgreSQL docs](https://www.postgresql.org/docs/current/upgrading.html#UPGRADING-VIA-REPLICATION)
.

## Upgrade Keycloak (major version)

From major version 20 to major version 21, there appears to be no database data
issue when pointing to the same database instance. From major version 20 to
major version 21, there may be a compatibility issue with
[the custom extensions](https://github.com/PhilanthropyDataCommons/auth), so the
extensions should be recompiled against the major version 21 API and tested 
prior to attempting the upgrade in production.
