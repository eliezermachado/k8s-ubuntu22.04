#!/bin/bash

set -e  # Para o script em caso de erro

# Definir a versão do Istio (última recomendada para K8s 1.30)
ISTIO_VERSION="1.24.3"

# Baixar e instalar o Istio
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$ISTIO_VERSION sh -
cd istio-$ISTIO_VERSION
export PATH=$PWD/bin:$PATH

# Instalar o Istio no cluster
istioctl install --set profile=demo -y

# Habilitar a injeção automática de sidecar no namespace default
kubectl label namespace default istio-injection=enabled --overwrite

# Configurar o Istio Ingress Gateway para usar LoadBalancer (compatível com MetalLB)
kubectl patch svc istio-ingressgateway -n istio-system -p '{"spec": {"type": "LoadBalancer"}}'

# Aguardar a atribuição de um IP pelo MetalLB
echo "Aguardando a atribuição de IP pelo MetalLB..."
sleep 10  # Ajuste o tempo conforme necessário
kubectl get svc istio-ingressgateway -n istio-system
