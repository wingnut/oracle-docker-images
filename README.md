## NOTE!!! Requires a Docker Engine allowing --squash for builds (typically achieved by enabling Docker experimental features) 

# Oracle Docker Images

> ⚠️ Docker image version 1.0 has a flaw! The user SYSTEM's password expires 03/05/2021. Upgrade to version 2.0 where the user SYSTEM's password never expires. 

This repo provides a script to automate the process of creating a prebuilt oracle docker image.

## Background
Oracle offers an [official enterprise database docker](https://hub.docker.com/_/oracle-database-enterprise-edition).

Using this official image requires users to agree to a [click through license agreement](https://www.oracle.com/downloads/licenses/standard-license.html). 

Additionally, the database is not built until runtime, meaning that container startup takes approx. 10 minutes.

## Licensing
Oracle offers their own scripts to create an oracle database docker image in the [oracle/docker-images](https://github.com/oracle/docker-images) GitHub repo under a [Universal Permissive License](https://github.com/oracle/docker-images/blob/master/LICENSE).

Again, this process requires users to download installation binaries from oracle, and by doing so requires user to agree to a [license agreement](https://www.oracle.com/downloads/licenses/standard-license.html). 

That was until oracle released the [Oracle Database 18c XE](https://blogs.oracle.com/database/oracle-database-18c-xe-now-under-the-oracle-free-use-terms-and-conditions-license-v2) binary under a [free use license](https://www.oracle.com/downloads/licenses/oracle-free-license.html), which grants users a license to:

```txt
(b) redistribute unmodified Programs and Programs Documentation, under the terms of this License, provided that You do not charge Your end users any additional fees for the use of the Programs.
```

## Prebuilt Database
The oracle images created from using the scripts from the [oracle/docker-images](https://github.com/oracle/docker-images) GitHub repo still create the database at runtime.

The script in this repository automates the [process documented by oracle](https://github.com/oracle/docker-images/tree/master/OracleDatabase/SingleInstance/samples/prebuiltdb) to create a database image with a pre-built database.

## Building image from source
Clone this repo, navigate to the source directory and run the `prebuild.sh` script.

```sh
git clone git@github.com:wingnut/oracle-docker-images.git
cd oracle-docker-images/src
./prebuild.sh
```

This script will do the following:
1. Clone the `oracle/docker-images` git repo
2. Make necessary edits to the `buildDockerImage.sh` and `18.4.0/Dockefile` files to create a prebuilt database image
3. Run the `buildDockerImage.sh` script to create a base image: `oracle/database:18.4.0-xe`
4. Run the base image `oracle/database:18.4.0-xe` which will create the database.
5. Commit this container to a new image `oracle/database:18.4.0-xe-prebuilt`
6. Clean up the intermediary containers, and remove the `oracle/docker-images` repo.

## Pull from dockerhub
```sh
docker pull wingnut/oracle-18.4.0-xe-prebuilt
```

## Publishing to dockerhub
To push this image to a **private** dockerhub repository.

Create a private repository named:
```txt
<dockerhub-username>/oracle-18.4.0-xe-prebuilt
```
Then run the `prebuild.sh` script with the push parameter.
```sh
# version is typically 1.0 or latest
./prebuild.sh -p -u <dockerhub-username> -v <dockerhub-version>
```
