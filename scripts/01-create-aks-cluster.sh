#! /bin/bash

set -o pipefail

# Create an AKS cluster with specified parameters
LOCATION=${1:-"westeurope"}
RESOURCE_GROUP=${2:-"myResourceGroup"}
CLUSTER_NAME=${3:-"myCluster"}
NODE_COUNT=${4:-2}
NODE_SIZE=${5:-"Standard_D2ps_v6"}
ADMIN_USERNAME=${6:-"exercise"}            # username created on the nodes (for SSH connections)
KUBERNETES_VERSION=${7:-"1.32.7"}          # specify Kubernetes version
LOAD_BALANCER_SKU=${8:-"Standard"}         # specify load balancer SKU
OUTBOUND_TYPE=${9:-"loadBalancer"}         # specify outbound type

SOURCE_IP_RANGES="$(curl --silent ifconfig.me; echo)/32"
[[ ! -z "$ADDITIONAL_ALLOWED_SOURCE_IP_RANGES" ]] && SOURCE_IP_RANGES="$SOURCE_IP_RANGES,$ADDITIONAL_ALLOWED_SOURCE_IP_RANGES"

# create the resource-group if needed
az group list --query "[?(name=='$RESOURCE_GROUP') && (location=='westeurope')]" --output tsv | grep -q $RESOURCE_GROUP > /dev/null
if [[ $? -ne 0 ]]; then
    printf "⚠️ Resource group '$RESOURCE_GROUP' does not exist. Creating it in location '$LOCATION'...\n"
    az group create --name $RESOURCE_GROUP --location $LOCATION
    if [[ $? -ne 0 ]]; then
        printf "❌ Failed to create resource group '$RESOURCE_GROUP'.\n" >&2
        exit 1
    fi
    printf "✅ Resource group '$RESOURCE_GROUP' created.\n\n"
fi

# create the Public IP Prefix to expose the nodes of the cluster directly over the internet
PUBLIC_IP_PREFIX_ID=$(az network public-ip prefix create --length 31 --location $LOCATION --name "${CLUSTER_NAME}-publicIPPrefix" --resource-group $RESOURCE_GROUP | jq -r '.id')
[[ -z "$PUBLIC_IP_PREFIX_ID" ]] && {
    printf "❌ Failed to create Public IP Prefix for the cluster.\n\n" >&2
    exit 1
}

# create the AKS cluster
az aks create \
    --location $LOCATION \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --admin-username $ADMIN_USERNAME \
    --api-server-authorized-ip-ranges "$SOURCE_IP_RANGES" \
    --auto-upgrade-channel patch \
    --dns-name-prefix $CLUSTER_NAME \
    --dns-service-ip 172.16.0.10 \
    --enable-app-routing \
    --enable-node-public-ip \
    --node-public-ip-prefix-id $PUBLIC_IP_PREFIX_ID \
    --k8s-support-plan KubernetesOfficial \
    --kubernetes-version $KUBERNETES_VERSION \
    --load-balancer-sku $LOAD_BALANCER_SKU \
    --location $LOCATION \
    --max-pods 110 \
    --network-dataplane azure \
    --network-plugin azure \
    --network-plugin-mode overlay \
    --network-policy calico \
    --node-count $NODE_COUNT \
    --node-vm-size $NODE_SIZE \
    --os-sku Ubuntu \
    --outbound-type $OUTBOUND_TYPE \
    --service-cidr 172.16.0.0/16 \
    --pod-cidr 192.168.0.0/16 \
    --sku base \
    --generate-ssh-keys \
    --ssh-key-value $HOME/.ssh/id_${CLUSTER_NAME}_rsa.pub \
    --tier free \
    --zones 1 2 3 \
    --yes

if [[ $? -ne 0 ]]; then
    printf "❌ Failed to create the cluster." >&2
    printf "🧹 cleaning SSH keys...\n\n" >&2
    rm -f $HOME/.ssh/id_${CLUSTER_NAME}_rsa
    rm -f $HOME/.ssh/id_${CLUSTER_NAME}_rsa.pub
    exit 1
fi
printf "✅ AKS cluster '$CLUSTER_NAME' created in resource group '$RESOURCE_GROUP' with $NODE_COUNT nodes of size '$NODE_SIZE' in location '$LOCATION'.\n\n"

# generate the kubeconfig file
az aks get-credentials \
    --resource-group $RESOURCE_GROUP \
    --name $CLUSTER_NAME \
    --file $HOME/.kube/$CLUSTER_NAME.yaml \
    --overwrite-existing \
    --admin

if [[ $? -ne 0 ]]; then
    printf "❌ Failed to generate the kubeconfig file.\n\n" >&2
    exit 1
fi
printf "✅ Kubeconfig file generated at '$HOME/.kube/$CLUSTER_NAME.yaml'.\n\n"
