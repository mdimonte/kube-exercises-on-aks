# AKS

This repo is about creating a simple AKS cluster and preparing it for some exercises.

## Prerequisites

1. have an Azure account. You can get a free trial one using these instructions [here](https://azure.microsoft.com/en-us/free/search/?ef_id=_k_CjwKCAiA8NKtBhBtEiwAq5aX2BsBLk0gWTyFDQl8oL8pl7dtHtDI4YWq7opjgeJjtb5tIbAWBdiAsxoCqiEQAvD_BwE_k_&OCID=AIDcmm0g9y8ggq_SEM__k_CjwKCAiA8NKtBhBtEiwAq5aX2BsBLk0gWTyFDQl8oL8pl7dtHtDI4YWq7opjgeJjtb5tIbAWBdiAsxoCqiEQAvD_BwE_k_&gad_source=1&gclid=CjwKCAiA8NKtBhBtEiwAq5aX2BsBLk0gWTyFDQl8oL8pl7dtHtDI4YWq7opjgeJjtb5tIbAWBdiAsxoCqiEQAvD_BwE)
2. go to the [Azure portal](https://portal.azure.com)

   - navigate to `Cost Management + Billing`
   - select `Budget`
   - create a budget, set it to 180$ and set some associated alerts (i.e. 50%, 80%, 95%) to be notified when these thresholds are met

3. install the Azure CLI (`az`) using these instructions [here](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-linux?pivots=apt)
4. login to Azure with the CLI

   ```bash
   az login
   ```

## Create an AKS cluster

```bash
# optional: set additional IP@ to be allowed to access the API-Server
export ADDITIONAL_ALLOWED_SOURCE_IP_RANGES="1.2.3.4/32,5.6.7.0/27"

# create the AKS cluster (using default values)
# the RG will be created if it does not exist yet
scripts/01-create-aks-cluster.sh westeurope rg-test cluster-test
```

## Allow SSH connexions to worker nodes 

```bash
# optional: set additional IP@ to be allowed to access the API-Server
export ADDITIONAL_ALLOWED_SOURCE_IP_RANGES="1.2.3.4/32,5.6.7.0/27"

# if needed, allow the SSH inbound traffic to the nodes of the cluster
scripts/scripts/02-allow-ssh-to-nodes.sh westeurope rg-test cluster-test
```

## Implement the exercises into the AKS cluster

```bash
scripts/03-implement-exercices.sh rg-test cluster-test
```

## Stop/start the cluster

```bash
# stopping the cluster
az aks stop --resource-group rg-test --name cluster-test 

# starting the cluster
az aks start --resource-group rg-test --name cluster-test 
```

## Teardown

```
az aks delete --resource-group rg-test --name cluster-test --yes
az group delete --name rg-test --yes
```
