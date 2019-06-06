#!/bin/bash

fold_start() {
  echo -e "travis_fold:start:$1\033[33;1m$2\033[0m"
}

fold_end() {
  echo -e "\ntravis_fold:end:$1\r"
}

set -eux

# Is there a standard interface name?
for iface in eth0 ens4 enp0s3; do
  IP=$(ifconfig $iface | grep 'inet addr' | cut -d: -f2 | awk '{print $1}');
  if [ -n "$IP" ]; then
    echo "IP: $IP"
    break
  fi
done
if [ -z "$IP" ]; then
  echo "Failed to get IP, current interfaces:"
  ifconfig -a
  exit 2
fi

TEST_NAMESPACE=omero-test

helm dependency update ./omero-server/
helm dependency update ./omero-web/

helm install --name omero-server --namespace $TEST_NAMESPACE ./omero-server/ \
  -f minikube-omero-server.yaml $HELM_EXTRA_ARGS
helm install --name omero-web --namespace $TEST_NAMESPACE ./omero-web/ \
  -f minikube-omero-web.yaml $HELM_EXTRA_ARGS

echo "waiting for omero-server"
n=0
until [ "`kubectl -n $TEST_NAMESPACE get statefulset omero-server -o jsonpath='{.status.readyReplicas}'`" = 1 ]; do
  let ++n
  if [ $(( $n % 12 )) -eq 0 ]; then
    kubectl -n $TEST_NAMESPACE describe pod
  else
    kubectl -n $TEST_NAMESPACE get pod
  fi
  sleep 10
done

echo "waiting for omero-web"
n=0
until [ "`kubectl -n $TEST_NAMESPACE get deploy omero-web -o jsonpath='{.status.readyReplicas}'`" = 1 ]; do
  let ++n
  if [ $(( $n % 12 )) -eq 0 ]; then
    kubectl -n $TEST_NAMESPACE describe pod
  else
    kubectl -n $TEST_NAMESPACE get pod
  fi
  sleep 10
done

display_logs() {
  fold_start logs.1 "Display kubernetes logs"
  # May crash on Travis:
  #echo "***** minikube *****"
  #minikube logs
  echo "***** node *****"
  kubectl describe node
  echo "***** pods *****"
  kubectl --namespace $TEST_NAMESPACE get pods
  echo "***** events *****"
  kubectl --namespace $TEST_NAMESPACE get events
  echo "***** hub *****"
  kubectl --namespace $TEST_NAMESPACE logs statefulset/omero-server
  echo "***** proxy *****"
  kubectl --namespace $TEST_NAMESPACE logs deploy/omero-web
  fold_end logs.1
}

display_logs
kubectl --namespace $TEST_NAMESPACE get pods