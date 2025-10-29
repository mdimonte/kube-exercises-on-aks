#! /bin/bash

set -o pipefail

RESOURCE_GROUP=${1:-"\$1_was_not_provided"}
CLUSTER_NAME=${2:-"\$2_was_not_provided"}
ADMIN_USERNAME=${3:-"exercise"}                 # username created on the nodes (for SSH connections)

export KUBECONFIG=$HOME/.kube/${CLUSTER_NAME}.yaml

# Function for Exercise #1: force the kubelet of the 1st node to fail starting
# ----------------------------------------------------------------------------
setup_exercise_1() {
    printf "Implementing Exercice #1: forcing the kubelet of the first node to fail starting...\n"
    NODE_RESOURCE_GROUP=$(az aks show --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --query "nodeResourceGroup" -o tsv)
    VMSS_NAME=$(az vmss list --resource-group $NODE_RESOURCE_GROUP --query "[0].name" -o tsv)
    FIRST_INSTANCE_IP=$(az vmss list-instance-public-ips --resource-group $NODE_RESOURCE_GROUP --name $VMSS_NAME --query "[0].ipAddress" -o tsv)
    ssh -i $HOME/.ssh/id_${CLUSTER_NAME}_rsa $ADMIN_USERNAME@$FIRST_INSTANCE_IP <<EOF
sudo sed -i -e 's|^ExecStart=/usr/local/bin/kubelet|ExecStart=/usr/local/bin/kubeletlet|' /etc/systemd/system/kubelet.service
sudo systemctl daemon-reload
sudo systemctl restart kubelet
EOF

    if [[ $? -ne 0 ]]; then
        printf "❌ Failed to modify the kubelet service on the first node ($FIRST_INSTANCE_IP).\n\n" >&2
        return 1
    fi
    printf "✅ The kubelet of the first node ($FIRST_INSTANCE_IP) has been forced to fail starting.\n"
    printf "You can connect using: ssh -i ~/.ssh/id_${CLUSTER_NAME}_rsa $ADMIN_USERNAME@$FIRST_INSTANCE_IP\n\n"
    return 0
}

# Function for Exercise #2: pod not starting due to PSS/PSA violation and not tolerating node taints
# --------------------------------------------------------------------------------------------------
setup_exercise_2() {
    printf "Implementing Exercice #2: applying a taint on all worker nodes...\n"
    kubectl taint nodes --all dedicated=special-app:NoSchedule --overwrite
    if [[ $? -ne 0 ]]; then
        printf "❌ Failed to taint the nodes of the cluster.\n\n" >&2
        return 1
    fi
    printf "✅ All nodes have been tainted with 'dedicated=special-app:NoSchedule'.\n\n"

    printf "Implementing Exercice #2: creating a deployment whose pods violate Pod Security Standards...\n"
    kubectl apply -f $(dirname $0)/../manifests/exercise-2.yaml
    if [[ $? -ne 0 ]]; then
        printf "❌ Failed to create the deployment in the 'exercise-2' namespace.\n\n" >&2
        return 1
    fi
    printf "✅ A deployment has been created in the 'exercise-2': Pods are rejected due to Pod Security Standards violation and not tolerating node taints.\n\n"
    return 0
}

# Function for Exercise #3: app that does not work due to NetworkPolicy
# ---------------------------------------------------------------------
setup_exercise_3() {
    printf "Implementing Exercice #3: creating two pods that cannot communicate due to a restrictive NetworkPolicy...\n"
    kubectl apply -f $(dirname $0)/../manifests/exercise-3.yaml
    if [[ $? -ne 0 ]]; then
        printf "❌ Failed to create the Deployments, Service or NetworkPolicy in the 'exercise-3' namespace.\n\n" >&2
        return 1
    fi
    printf "✅ The Deployments, Service and NetworkPolicy have been created in the 'exercise-3' namespace so that network connectivity fails due to a restrictive NetworkPolicy.\n\n"
    return 0
}

# Function for Exercise #4: PVC not ending up in a PV because the storageclass referenced is invalid
# --------------------------------------------------------------------------------------------------
setup_exercise_4() {
    printf "Implementing Exercice #4: creating a PVC that cannot bind to a PV due to an invalid StorageClass...\n"
    kubectl apply -f $(dirname $0)/../manifests/exercise-4.yaml
    if [[ $? -ne 0 ]]; then
        printf "❌ Failed to create the PVC in the 'exercise-4' namespace.\n\n" >&2
        return 1
    fi
    printf "✅ A PVC has been created in the 'exercise-4' namespace that cannot bind to a PV due to an invalid StorageClass name.\n\n"
    return 0
}

# Main function to control exercises setup
# ----------------------------------------
main() {
    setup_exercise_1
    setup_exercise_2
    setup_exercise_3
    setup_exercise_4
}

# Execute main function with all arguments
main "$@"
