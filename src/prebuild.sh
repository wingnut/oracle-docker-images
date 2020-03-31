#!/bin/bash
# Script built to create a prebuilt oracle database using the instructions here: 
#   https://github.com/oracle/docker-images/tree/master/OracleDatabase/SingleInstance/samples/prebuiltdb

#----- ARGUMENTS ------#
while getopts "o:cpu:v:?h" optname; do
  case "$optname" in
    "o") ORACLE_VERSION="$OPTARG" ;;
    "c") CLEAN=true ;;
    "p") DOCKER_PUSH=true ;;
    "u") DOCKER_USER="$OPTARG" ;;
    "v") DOCKER_VERSION="$OPTARG" ;;
    "h|?") usage; exit 1; ;;
    # Should not occur
    *) echo "Unknown error while processing options inside prebuild.sh" ;;
  esac
done

usage() {
  cat << EOF
Usage: prebuild.sh [-p [push] -u <docker-username> -v <docker-version>] [-?|-h help]
Builds a Docker Image for Oracle Database.
  
Parameters:
   -o: oracle database version to use
   -c: cleanup artifacts when done
   -p: perform a docker push after prebuilt database is created
      -u: (required) your dockerhub username
      -v: (required) version of resulting dockerhub image (ex 1.0, latest)
   -h|?: Help
EOF
}

#----- VARIABLES ------#
#Working directories
DIR=$(pwd)
GIT_FOLDER="$DIR/docker-images"

# Image information example: oracle/database:18.4.0-xe (prefix)/(postfix):(version)-(build)
PREFIX="oracle"                 #Constant
POSTFIX="database"              #Constant
VERSION="18.4.0"                #Accept alternative version in the future if other binaries are released under free use.
BUILD="xe"                      #The XE version will always be the smallest.  Not recommended to run any other version in a docker environment.
BUILD_FINAL="$BUILD-prebuilt"

# Docker arguments provided at build and runtime
BUILD_ARGS="--squash"
RUN_ARGS=""

# Check if user defined an alternative version
# Commented out because besides 18.4.0 you need to download binaries ahead of time
if [ ! -z "$ORACLE_VERSION" ]; then
   VERSION=$ORACLE_VERSION
fi

#Runtime arguments
if [ "$VERSION" = "11.2.0.2" ]; then
    RUN_ARGS="--shm-size=1g"
fi

# Base image information
BASE_IMAGE="${PREFIX}/${POSTFIX}:${VERSION}-${BUILD}"

# Final image information
FINAL_IMAGE="${PREFIX}/${POSTFIX}:${VERSION}-${BUILD_FINAL}"

#Intermediate image information
INTERMEDIATE_BUILD="oracle-build"

#----- FUNCTIONS ------#
# Output using color to denote this scripts output
echoWithColor() {
    GREEN="\033[1;32m"
    NOCOLOR="\033[0m"
    IN=$1
    echo -e $GREEN$IN$NOCOLOR
}

# Set IMAGE_ID to the results of searching docker for the provided image name
getImageID() {
    IMAGE_ID=$(docker images -q $1)
    echoWithColor "Docker image id for $1 : $IMAGE_ID"
}

# Clone the orace/docker-images repository into this directory
gitCloneOracle() {
    # Make sure folder directory doesn't already exist, otherwise, this call would fail
    local URL="git@github.com:oracle/docker-images.git"
    if [ ! -d "$GIT_FOLDER" ] ; then
        echoWithColor "---> Cloning Oracle Docker Image"
        git clone "$URL" "$GIT_FOLDER"
        echoWithColor "<--- Cloning Oracle Docker Image"
    else 
        echoWithColor "$GIT_FOLDER already exists, not cloning dit repository."
    fi
}

# Edit necessary files to build a base image that will only build the database once.
dockerBuildBase() {
    echoWithColor "---> Building Base Image"
    cd $DIR/docker-images/OracleDatabase/SingleInstance/dockerfiles/
    
    # Remove volume to persist database inside container
    sed -i '' 's/VOLUME.*/#VOLUME/' ./$VERSION/Dockerfile.xe
    # Increase start-period to 15 minutes to ensure we do not fall into an unhealthy state
    sed -i '' 's/HEALTHCHECK.*/HEALTHCHECK --interval=1m --start-period=15m\\ /' ./$VERSION/Dockerfile.xe
    # MAC OS seems to stall when calling the yes command to remove an intermediary image
    # This image will be removed during the cleanup stage instead
    sed -i '' 's/yes.*/#yes/' ./buildDockerImage.sh

    # Execute build command
    ./buildDockerImage.sh -v $VERSION -x -o $BUILD_ARGS

    # Back to base directory
    cd $DIR

    echoWithColor "<--- Building Base Image"
}

# This is when the database will be created, and the password is set.
dockerRunBase() {    
    echoWithColor "---> Building Database Image"
    docker run --name ${INTERMEDIATE_BUILD} -p 1521:1521 -p 5500:5500 -e ORACLE_PWD=oracle ${RUN_ARGS} ${BASE_IMAGE}
    echoWithColor "<--- Building Database Image"
}

# Continuously inspects "INTERMEDIATE_BUILD" and waits for a healthy status before stopping the container
waitForHealthCheck() {
    local HEALTH_STRING="healthy"
    echoWithColor "Wait until container is healthy (Approx. 10 minutes)"
    sleep 10 #wait for container to be created

    #Check every 15 seconds to see if status is healthy
    until docker inspect --format='{{json .State.Health}}' $INTERMEDIATE_BUILD | grep -w -q $HEALTH_STRING > /dev/null
    do
        sleep 15
    done

    echoWithColor "Docker instance found to be healthy. Stopping container"

    # Stop container
    docker stop -t 30 ${INTERMEDIATE_BUILD}
}

# Cleanup leftover containers, dangling images, and intermediary images.
cleanup() {
    echoWithColor "---> Cleaning Up"
    docker rm $INTERMEDIATE_BUILD
    docker rmi $(docker images -f dangling=true -q)
    rm -rf $GIT_FOLDER
    # Uncomment to remove base image.  Not on by default incase you want to inspect / use base image. 
    # docker rmi ${BASE_IMAGE}
    echoWithColor "<--- Cleaning Up"
}

dockerPush() {
    docker login
    docker tag $PREFIX/$POSTFIX:$VERSION-$BUILD_FINAL $DOCKER_USER/$PREFIX-$VERSION-$BUILD_FINAL:$DOCKER_VERSION
    docker push $DOCKER_USER/$PREFIX-$VERSION-$BUILD_FINAL:$DOCKER_VERSION
}

#----- MAIN PROGRAM ------#

# Do the base or final images already exist?
getImageID $BASE_IMAGE
BASE_IMAGE_ID=$IMAGE_ID

getImageID $FINAL_IMAGE
FINAL_IMAGE_ID=$IMAGE_ID

# If base image does not exist, clone directory and build it.
if [ ! "${BASE_IMAGE_ID}" ]; then
    gitCloneOracle
    dockerBuildBase
else 
    echoWithColor "${BASE_IMAGE} image already exists, skipping build step."
fi

# If final image does not exist, run base image to build database, and wait for a healthy start.
# Once healthy commit image, and cleanup
if [ ! "${FINAL_IMAGE_ID}" ]; then
    #Launch in two threads and wait for both to finish
    dockerRunBase &         # Starts container
    waitForHealthCheck &    # Stops container once healthy
    wait

    # Commit container so it can be reused as a prebuilt image. 
    docker commit -m "oracle prebuilt database" ${INTERMEDIATE_BUILD} ${FINAL_IMAGE}

    # Cleanup leftover junk
    if [ $CLEAN ]; then
        cleanup
    fi
else
    echoWithColor "${FINAL_IMAGE} image already exists, skipping build step."
fi

# Push to dockerhub
if [ $DOCKER_PUSH ]; then
    if [[ -z "$DOCKER_USER" || -z "$DOCKER_VERSION" ]]; then
        echoWithColor "Unable to push $FINAL_IMAGE to dockerhub.  One or more variables are undefined. User: $DOCKER_USER Version: $DOCKER_VERSION"
    else
        dockerPush
    fi
fi