#!/bin/bash

if ! command -v helm &> /dev/null; then
  echo "Helm não encontrado. Instalando..."
  curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 
  chmod 700 get_helm.sh 
  ./get_helm.sh
else
  echo "Helm já está instalado."
fi

# Adiciona o repositório do Metrics Server
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update

# Verifica se o Metrics Server já está instalado
if helm list -n kube-system | grep -q "metrics-server"; then
  echo "Metrics Server já está instalado."
else
  echo "Instalando Metrics Server..."
  helm install metrics-server metrics-server/metrics-server \
    --namespace kube-system \
    --set args={"--kubelet-insecure-tls"}
fi

# Adiciona o repositorio do Prometheus e Grafana:
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update


if helm list -n monitoring | grep -q "prometheus"; then
  echo "Prometheus Server já está instalado."
else
  echo "Instalando Prometheus Server..."
  helm install monitoring prometheus-community/kube-prometheus-stack -n monitoring --create-namespace
fi