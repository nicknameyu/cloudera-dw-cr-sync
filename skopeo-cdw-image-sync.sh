#!/bin/bash

#set -x
# Initialize variables
SOURCE_USER=""
SOURCE_PASS=""
DEST_USER=""
DEST_PASS=""
DESTINATION_REGISTRY=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --source-cr-user)
      SOURCE_USER="$2"
      shift 2
      ;;
    --source-cr-password)
      SOURCE_PASS="$2"
      shift 2
      ;;
    --destination-cr-user)
      DEST_USER="$2"
      shift 2
      ;;
    --destination-cr-password)
      DEST_PASS="$2"
      shift 2
      ;;
    --destination-cr)
      DESTINATION_REGISTRY="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Prompt for missing values
while [ -z "$DESTINATION_REGISTRY" ]; do
  read -s -p "Enter destination container registry FQDN: " DESTINATION_REGISTRY
  echo
done

while [ -z "$SOURCE_USER" ]; do
  read -p "Enter source container registry username: " SOURCE_USER
done

while [ -z "$SOURCE_PASS" ]; do
  read -s -p "Enter source container registry password: " SOURCE_PASS
  echo
done

while [ -z "$DEST_USER" ]; do
  read -p "Enter destination container registry username: " DEST_USER
done

while [ -z "$DEST_PASS" ]; do
  read -s -p "Enter destination container registry password: " DEST_PASS
  echo
done

echo "[INFO]: Start copying container images from Cloudera Container Registry to ${DESTINATION_REGISTRY}"
echo "[INFO]: Login to cloudera container registry "
skopeo login -u "$SOURCE_USER" -p "$SOURCE_PASS" container.repo.cloudera.com
if [ $? -ne 0 ]; then
    echo "[ERROR]: Failed login to Cloudera container registry."
    exit 1
fi
echo "[INFO]: Login to destination registry "
skopeo login -u "$DEST_USER" -p "$DEST_PASS" "$DESTINATION_REGISTRY"
if [ $? -ne 0 ]; then
    echo "[ERROR]: Failed login to destination registry."
    exit 2
fi
FAILED_IMAGE=()
echo [INFO]: Downloading manifest file.
image_list=$(curl -L -s -u ${SOURCE_USER}:${SOURCE_PASS} https://archive.cloudera.com/p/dwx/1/release_manifest.json | jq -r '.images[].paths[] | "\(.path),\(.version)"')
if [ $? -ne 0 ]; then
    echo "[ERROR]: Failed downloading manifest file."
    exit 3
fi

# Progress bar variables
i=1
size=$(echo "$image_list" | wc -l)
GREEN='\033[0;32m'
RESET='\033[0m'

for CDW_IMAGE in $image_list
do
    BASE_DIR=$(dirname $(echo ${CDW_IMAGE} | sed 's|,| |' | awk '{print $1}'))
    IMAGE_NAME=$(basename $(echo ${CDW_IMAGE} | sed 's|,| |' | awk '{print $1}'))
    IMAGE_VERSION=$(echo ${CDW_IMAGE} | sed 's|,| |' | awk '{print $NF}')
    echo "[INFO]: Copying docker://container.repo.cloudera.com/${BASE_DIR}/${IMAGE_NAME}:${IMAGE_VERSION}"
    skopeo copy --all docker://container.repo.cloudera.com/${BASE_DIR}/${IMAGE_NAME}:${IMAGE_VERSION} docker://${DESTINATION_REGISTRY}/${BASE_DIR}/${IMAGE_NAME}:${IMAGE_VERSION}
    if [ $? -ne 0 ]; then
        echo "[ERROR]: Failed copying docker://container.repo.cloudera.com/${BASE_DIR}/${IMAGE_NAME}:${IMAGE_VERSION}."
        FAILED_IMAGE+=("${CDW_IMAGE}")
    else
        echo "[INFO]: Succeeded copying docker://container.repo.cloudera.com/${BASE_DIR}/${IMAGE_NAME}:${IMAGE_VERSION}."
    fi

    # progress bar
    echo "Processing item $i..."

    # Move cursor up one line and overwrite the progress bar
    echo -ne "\033[1A"  # Move cursor up one line
    echo -ne "\033[2K"  # Clear the line

    # Build and print progress bar
    percent=$((i * 100 / size))
    filled=$((i * 50 / size))
    empty=$((50 - filled))

    printf "${GREEN}\rProgress: ["
    printf "%0.s#" $(seq 1 $filled)
    printf "%0.s " $(seq 1 $empty)
    printf "] %3d%%${RESET}\n" $percent  # \n to stay on bottom line
    ((i++))
done

if [ ${#FAILED_IMAGE[@]} -gt 0 ]; then
    echo "skopeo copy failed for below images:"
    for item in "${FAILED_IMAGE[@]}"; do
        echo $item
    done
else
    echo "[INFO] All images are copied successfully."
fi