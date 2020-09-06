#!/bin/bash

echo "Health-check"

HOST=$(yq -r .hostname ./variables/${DEPLOY_ENV}.yaml)
echo "HOST: ${HOST}"

if [ -z "$HOST" ]; then
  echo "$HOST can not be empty"
  exit 1
fi

if [ -z "$NAMESPACE" ]; then
  echo "$NAMESPACE can not be empty"
  exit 1
fi

PROJECT_NAME=$(yq -r .project ./variables/${DEPLOY_ENV}.yaml)
if [[ "${PROJECT_NAME}" =~ [^a-z] ]]; then
   echo "project name can be only lower-case [a-z], no special signs"
   exit 1
fi

echo "Deploying into $NAMESPACE"

kubectl create namespace ${NAMESPACE}

K8S_DIR=./manifests
TARGET_DIR=${K8S_DIR}/.generated

mkdir -p ${TARGET_DIR}

mkdir -p certs

FILE=./certs/${DEPLOY_ENV}/${HOST}.key

if [ ! -f "$FILE" ]; then
    echo "$FILE does not exist, creating self-signed certs for ${HOST}"
    mkdir -p ./certs/${DEPLOY_ENV}/
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout ./certs/${DEPLOY_ENV}/${HOST}.key -out ./certs/${DEPLOY_ENV}/${HOST}.crt -subj "/CN=$HOST"
fi

# We do not delete the secret since it is not supposed to be overwritten
# only initially created as self-signed for the ingress to get deployed
# after that let's encrypt is responsible for managing it
#kubectl --namespace=$NAMESPACE delete secret ${HOST}secret
echo "Create initial secret with self-signed cert"
kubectl --namespace=$NAMESPACE create secret tls ${PROJECT_NAME}secret --key ./certs/${DEPLOY_ENV}/${HOST}.key --cert ./certs/${DEPLOY_ENV}/${HOST}.crt

echo "Expanding yaml files"
for f in ${K8S_DIR}/*.yaml
do
  jinja2 $f ./variables/${DEPLOY_ENV}.yaml \
  --format=yaml --strict \
  > "${TARGET_DIR}/$(basename ${f})"
done

echo "Deploying"
kubectl --namespace=$NAMESPACE apply -f ${TARGET_DIR}