# Cloudera Data Warehouse Container Registry Sync

This repository provides shell scripts to synchronize container images required for Cloudera Data Warehouse (CDW) on Azure. It includes two scripts:

- `az-cdw-image-sync.sh`: Uses Azure CLI to synchronize images.
- `skopeo-cdw-image-sync.sh`: Uses `skopeo` to copy images between registries.

## Prerequisites

Ensure the following tools are installed and configured:

- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
- [skopeo](https://github.com/containers/skopeo)
- [jq](https://stedolan.github.io/jq/)

## Usage

### Using Azure CLI

```bash
./az-cdw-image-sync.sh --source-cr-user myuser \
                       --source-cr-password mypass \
                       --acr-name myacr
```
Options:
  --source-cr-user USERNAME       Username for the source container registry (required)
  --source-cr-password PASSWORD   Password or token for the source container registry (required)
  --acr-name NAME                 Azure Container Registry (ACR) name (required)

### Using skopeo
`skopeo-cdw-image-sync.sh` has stricter environment requirement. It sometimes doesn't work very well.

Options:
  --source-cr-user USERNAME         Username for the source container registry (required)
  --source-cr-password PASSWORD     Password or token for the source container registry (required)
  --destination-cr-user USERNAME    Username for the destination container registry (required)
  --destination-cr-password PASSWORD
                                    Password or token for the destination container registry (required)
  --destination-cr REGISTRY_URL     Destination container registry (required)

```bash
./script.sh --source-cr-user sourceuser \
            --source-cr-password sourcepass \
            --destination-cr-user destuser \
            --destination-cr-password destpass \
            --destination-cr myacr.azurecr.io
```