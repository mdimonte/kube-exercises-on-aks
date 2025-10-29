#! /bin/bash

set -o pipefail

RESOURCE_GROUP=${1:-"\$1_was_not_provided"}
CLUSTER_NAME=${2:-"\$2_was_not_provided"}
ADMIN_USERNAME=${3:-"exercise"}                 # username created on the nodes (for SSH connections)

SOURCE_IP_RANGES="$(curl --silent ifconfig.me; echo)/32"
[[ ! -z "$ADDITIONAL_ALLOWED_SOURCE_IP_RANGES" ]] && SOURCE_IP_RANGES="$SOURCE_IP_RANGES $ADDITIONAL_ALLOWED_SOURCE_IP_RANGES"

# Allow inbound SSH connections to the nodes of the cluster
# from My IP and those documented in ADDITIONAL_ALLOWED_SOURCE_IP_RANGES
NODE_RESOURCE_GROUP=$(az aks show --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --query "nodeResourceGroup" -o tsv)
VMSS_NAME=$(az vmss list --resource-group $NODE_RESOURCE_GROUP --query "[0].name" -o tsv)
FIRST_INSTANCE_IP=$(az vmss list-instance-public-ips --resource-group $NODE_RESOURCE_GROUP --name $VMSS_NAME --query "[0].ipAddress" -o tsv)
NSG_NAME=$(az network nsg list --resource-group $NODE_RESOURCE_GROUP --query "[0].name" -o tsv)
az network nsg rule create \
    --resource-group $NODE_RESOURCE_GROUP \
    --nsg-name $NSG_NAME \
    --name "allow-inbound-ssh" \
    --protocol Tcp \
    --priority 1000 \
    --destination-port-range 22 \
    --source-address-prefixes $SOURCE_IP_RANGES \
    --destination-address-prefixes "VirtualNetwork" \
    --access Allow \
    --direction Inbound

if [[ $? -ne 0 ]]; then
    printf "❌ Failed to create NSG rule to allow SSH access to the nodes.\n\n" >&2
    exit 1
fi

printf "✅ SSH access to the first node ($FIRST_INSTANCE_IP) allowed from: $SOURCE_IP_RANGES\n"
printf "You can connect using: ssh -i ~/.ssh/id_${CLUSTER_NAME}_rsa $ADMIN_USERNAME@$FIRST_INSTANCE_IP\n\n"
