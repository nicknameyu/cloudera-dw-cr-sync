#!/bin/bash

#set -x
# Initialize variables
SOURCE_USER=""
SOURCE_PASS=""
ACR_NAME=""

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
    --acr-name)
      ACR_NAME="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Prompt for missing values
while [ -z "$ACR_NAME" ]; do
  read -s -p "Enter Azure Container Registry name: " ACR_NAME
  echo
done

while [ -z "$SOURCE_USER" ]; do
  read -p "Enter source container registry username: " SOURCE_USER
done

while [ -z "$SOURCE_PASS" ]; do
  read -s -p "Enter source container registry password: " SOURCE_PASS
  echo
done


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

    # Process image import
    BASE_DIR=$(dirname $(echo ${CDW_IMAGE} | sed 's|,| |' | awk '{print $1}'))
    IMAGE_NAME=$(basename $(echo ${CDW_IMAGE} | sed 's|,| |' | awk '{print $1}'))
    IMAGE_VERSION=$(echo ${CDW_IMAGE} | sed 's|,| |' | awk '{print $NF}')

    # Check existance. if exists, skip
    echo [INFO]: Checking exsitance of repository $BASE_DIR/$IMAGE_NAME:$IMAGE_VERSION
    az acr repository show -n $ACR_NAME --repository "$BASE_DIR/$IMAGE_NAME" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        # Repo exists, checking tag
        az acr repository show-tags -n $ACR_NAME --repository "$BASE_DIR/$IMAGE_NAME" | jq -r '.[]' |grep $IMAGE_VERSION > /dev/null 2>&1
        if [ $? -eq 0 ]; then
        # Version exists, skipping
            echo [INFO]: Repository $BASE_DIR/$IMAGE_NAME:$IMAGE_VERSION exists. Skipping import.
            continue
        fi
    fi
    echo "[INFO]: Importing docker://container.repo.cloudera.com/${BASE_DIR}/${IMAGE_NAME}:${IMAGE_VERSION}"
    az acr import \
        --name $ACR_NAME \
        --source container.repo.cloudera.com/${BASE_DIR}/${IMAGE_NAME}:${IMAGE_VERSION} \
        --image ${BASE_DIR}/${IMAGE_NAME}:${IMAGE_VERSION} \
        --username "$SOURCE_USER" \
        --password "$SOURCE_PASS"

    if [ $? -ne 0 ]; then
        echo "[ERROR]: Failed copying docker://container.repo.cloudera.com/${BASE_DIR}/${IMAGE_NAME}:${IMAGE_VERSION}."
        FAILED_IMAGE+=("${CDW_IMAGE}")
    else
        echo "[INFO]: Succeeded imported docker://container.repo.cloudera.com/${BASE_DIR}/${IMAGE_NAME}:${IMAGE_VERSION}."
    fi

done

if [ ${#FAILED_IMAGE[@]} -gt 0 ]; then
    echo "[ERROR] copy failed for below images:"
    for item in "${FAILED_IMAGE[@]}"; do
        echo $item
    done
else
    echo "[INFO] All images are copied successfully."
fi
