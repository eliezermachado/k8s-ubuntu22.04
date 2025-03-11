#!/bin/bash

# Defina o intervalo de IPs que o MetalLB usará
IP_RANGE="10.200.254.200-10.200.254.210"  # Ajuste conforme sua rede

# Cria o namespace do MetalLB
kubectl create namespace metallb-system || echo "Namespace já existe"

# Instala o MetalLB v0.14.9 a partir dos manifestos oficiais
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.9/config/manifests/metallb-native.yaml

# Aguarda os pods do MetalLB iniciarem
echo "Aguardando o MetalLB iniciar..."
kubectl wait --namespace metallb-system \
  --for=condition=Available deployment controller \
  --timeout=120s

# Aplica a configuração do MetalLB com o intervalo de IPs definido
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: metallb-system
spec:
  addresses:
  - $IP_RANGE
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: first-advert
  namespace: metallb-system
EOF

echo "MetalLB v0.14.9 instalado e configurado com o intervalo de IPs: $IP_RANGE"
