#!/bin/bash

set -e  # Para interromper o script em caso de erro

# Verifica se o Helm está instalado
if ! command -v helm &> /dev/null; then
  echo "Helm não encontrado. Instalando..."
  curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 
  chmod 700 get_helm.sh 
  ./get_helm.sh
else
  echo "Helm já está instalado."
fi

# Adiciona o repositório do Istio
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update

# Função para verificar se um release já está instalado no Helm
check_helm_release() {
  local release=$1
  local namespace=$2
  helm list -n "$namespace" | grep -q "$release"
}

# Instalação do Istio Base
if check_helm_release "istio-base" "istio-system"; then
  echo "Istio Base já está instalado."
else
  echo "Instalando Istio Base..."
  helm install istio-base istio/base -n istio-system --set defaultRevision=default --create-namespace
fi

# Instalação do Istiod
if check_helm_release "istiod" "istio-system"; then
  echo "Istiod já está instalado."
else
  echo "Instalando Istiod..."
  helm install istiod istio/istiod -n istio-system --create-namespace --wait
fi

# Instalação do Istio Ingress Gateway
if check_helm_release "istio-ingress" "istio-ingress"; then
  echo "Istio Ingress Gateway já está instalado."
else
  echo "Instalando Istio Ingress Gateway..."
  helm install istio-ingress istio/gateway -n istio-ingress --create-namespace --wait
fi

echo "Instalação do Istio concluída!"
