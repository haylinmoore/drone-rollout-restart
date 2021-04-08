#!/bin/sh

if [ -z ${PLUGIN_NAMESPACE} ]; then
  PLUGIN_NAMESPACE="default"
fi

if [ -z ${PLUGIN_KUBERNETES_USER} ]; then
  PLUGIN_KUBERNETES_USER="default"
fi

# Name of the cluster in .kube/config - Doesn't really matter
KUBERNETES_CLUSTER_NAME="cluster_name"
# Name of the context in .kube/config - Doesn't really matter
KUBERNETES_CONTEXT_NAME="context_name"

echo "Creating user entry and setting credentials in .kube/config"
kubectl config set-credentials ${PLUGIN_KUBERNETES_USER} --token=${PLUGIN_KUBERNETES_TOKEN}

echo "Creating cluster entry in .kube/config"
if [ ! -z ${PLUGIN_KUBERNETES_CERT} ]; then
  echo ${PLUGIN_KUBERNETES_CERT} | base64 -d > ca.crt
  kubectl config set-cluster ${KUBERNETES_CLUSTER_NAME} --server=${PLUGIN_KUBERNETES_SERVER} --certificate-authority=ca.crt
else
  echo "WARNING: Using insecure connection to cluster"
  kubectl config set-cluster ${KUBERNETES_CLUSTER_NAME} --server=${PLUGIN_KUBERNETES_SERVER} --insecure-skip-tls-verify=true
fi

echo "Creating context in .kube/config"
kubectl config set-context ${KUBERNETES_CONTEXT_NAME} --cluster=${KUBERNETES_CLUSTER_NAME} --user=${PLUGIN_KUBERNETES_USER}
echo "Setting context"
kubectl config use-context ${KUBERNETES_CONTEXT_NAME}

echo Rolling out to ${PLUGIN_DEPLOYMENT}
kubectl -n ${PLUGIN_NAMESPACE} rollout restart deployment ${PLUGIN_DEPLOYMENT}
