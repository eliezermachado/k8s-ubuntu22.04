#!/bin/bash
set -e # Interrompe o script se algum comando falhar

LOG_FILE="/var/log/k8s_install.log"
exec > >(tee -a "$LOG_FILE") 2>&1 # Redireciona stdout e stderr para o log

check_success() {
    if [ $? -eq 0 ]; then
        echo -e "✔️ $1 concluído com sucesso."
    else
        echo -e "❌ Erro ao executar: $1" >&2
        exit 1
    fi
}

# Função para configurar e validar o kubectl
configure_and_validate_kubectl() {
    echo "Configurando e validando o kubectl..."

    # Configurar o kubectl
    mkdir -p $HOME/.kube
    if sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config; then
        sudo chown $(id -u):$(id -g) $HOME/.kube/config
        echo "✔️ Arquivo de configuração do kubectl copiado com sucesso."
    else
        echo "❌ Falha ao copiar o arquivo de configuração do kubectl. Tentando método alternativo..."
        
        # Método alternativo: Gerar um novo token e configurar o kubectl
        if sudo kubeadm token create --print-join-command &>> "$LOG_FILE"; then
            echo "✔️ Novo token gerado com sucesso."
            if sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config; then
                sudo chown $(id -u):$(id -g) $HOME/.kube/config
                echo "✔️ Arquivo de configuração do kubectl copiado com sucesso (método alternativo)."
            else
                echo "❌ Falha ao copiar o arquivo de configuração do kubectl (método alternativo)."
                exit 1
            fi
        else
            echo "❌ Falha ao gerar novo token."
            exit 1
        fi
    fi

    # Validar o funcionamento do kubectl e o estado do cluster
    echo "Validando o funcionamento do kubectl e o estado do cluster..."
    if kubectl get nodes &>> "$LOG_FILE" && kubectl get pods -A &>> "$LOG_FILE"; then
        echo "✔️ kubectl está funcionando corretamente e o cluster está acessível."
    else
        echo "❌ Erro: kubectl não está funcionando corretamente ou o cluster não está acessível."
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

echo "Iniciando instalação do Kubernetes para arquitetura $ARCH"

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

echo "Ajuste Firewall - Control Plane"
sudo iptables -F
sudo iptables -X
sudo netfilter-persistent save

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
echo "Instalando Kubeadm, Kubelet e Kubectl versão $KUBERNETES_VERSION..."
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v$KUBERNETES_VERSION/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v$KUBERNETES_VERSION/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list > /dev/null
sudo apt-get update &>> "$LOG_FILE"
sudo apt-get install -y kubelet=1.30.0-1.1 kubectl=1.30.0-1.1 kubeadm=1.30.0-1.1 &>> "$LOG_FILE"
sudo apt-mark hold kubelet kubeadm kubectl

check_success "Instalação do Kubeadm, Kubelet e Kubectl"

# Passo 6: Inicializar o Cluster
echo "Inicializando o cluster..."
NODENAME=$(hostname -s)
POD_CIDR="10.30.0.0/16"
kubeadm init --pod-network-cidr=$POD_CIDR --node-name $NODENAME &>> "$LOG_FILE"

check_success "Inicialização do cluster"

# Passo 7: Configurar e validar o kubectl
configure_and_validate_kubectl

# Passo 8: Instalar o Plugin CNI (Calico)
echo "Instalando o Calico para rede dos pods..."
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml &>> "$LOG_FILE"

check_success "Instalação do Calico"