#!/bin/bash
set -e  # Interrompe o script se algum comando falhar

LOG_FILE="/var/log/k8s_join.log"
JOIN_COMMAND="commando-aqui"

exec > >(tee -a "$LOG_FILE") 2>&1  # Redireciona stdout e stderr para o log

check_success() {
  if [ $? -eq 0 ]; then
    echo -e "✔️ $1 concluído com sucesso."
  else
    echo -e " Erro ao executar: $1" >&2
    exit 1
  fi
}

# Detectar arquitetura do sistema
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    ARCH="amd64"
elif [ "$ARCH" = "aarch64" ]; then
    ARCH="arm64"
else
    echo "Arquitetura não suportada: $ARCH"
    exit 1
fi

echo "Iniciando join do nó ao cluster Kubernetes para arquitetura $ARCH..."

  # Passo 0: Ajuste IPTABLES
sudo apt update -y
sudo DEBIAN_FRONTEND=noninteractive apt install -y iptables-persistent

echo "Ajuste IPTABLES"
sudo iptables -F
sudo iptables -X
sudo netfilter-persistent save
check_success "Ajuste do IPTABLES"

# Passo 1: Configurar Módulos do Kernel e Rede
echo "Configurando módulos do kernel e rede..."
cat << EOF | sudo tee /etc/modules-load.d/k8s.conf > /dev/null
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

cat << EOF | sudo tee /etc/sysctl.d/k8s.conf > /dev/null
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system > /dev/null
check_success "Configuração de módulos do kernel e rede"

# Passo 2: Desativar swap
echo "Desativando swap..."
sudo swapoff -a
(crontab -l 2>/dev/null; echo "@reboot /sbin/swapoff -a") | crontab - || true
check_success "Desativação do swap"

# Passo 3: Instalar Containerd
echo "Instalando Containerd..."
sudo apt-get update &>> "$LOG_FILE"
sudo apt-get install -y containerd &>> "$LOG_FILE"
check_success "Instalação do Containerd"

# Passo 4: Configurar Containerd
echo "Configurando Containerd..."
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
check_success "Configuração do Containerd"

# Passo 5: Instalar Kubeadm, Kubelet e Kubectl
KUBERNETES_VERSION=1.30
echo "Instalando Kubeadm, Kubelet e Kubectl versão $KUBERNETES_VERSION para arquitetura $ARCH..."
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v$KUBERNETES_VERSION/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v$KUBERNETES_VERSION/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list > /dev/null

sudo apt-get update &>> "$LOG_FILE"
sudo apt-get install -y kubelet=1.30.0-1.1 kubectl=1.30.0-1.1 kubeadm=1.30.0-1.1 &>> "$LOG_FILE"
sudo apt-mark hold kubelet kubeadm kubectl
check_success "Instalação do Kubeadm, Kubelet e Kubectl"

# Passo 6: Executar o comando 'kubeadm join'
echo "Executando o comando 'kubeadm join'..."
$JOIN_COMMAND &>> "$LOG_FILE"
check_success "Join ao cluster realizado com sucesso"

# Passo 7: Verificar estado do nó
echo "Verificando estado do nó..."
kubectl get nodes &>> "$LOG_FILE"
echo "✔️ Nó adicionado ao cluster com sucesso! Para acompanhar os logs, use: tail -f $LOG_FILE"
