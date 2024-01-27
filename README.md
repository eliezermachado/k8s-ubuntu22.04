# Instalação do Kubernetes em um Servidor Ubuntu 22.04

Este guia fornece instruções passo a passo sobre como instalar o Kubernetes diretamente em um servidor Ubuntu 22.04.

## Requisitos Prévios

Primeira coisa, para que possamos seguir em frente, temos que entender quais são os pré-requisitos para a instalação do Kubernetes. Para isso, você pode consultar a documentação oficial do Kubernetes, mas vou listar aqui os principais pré-requisitos:

- Ubuntu Sever 22.04

- 2 GB ou mais de RAM por máquina (menos de 2 GB não é recomendado)

- 2 CPUs ou mais

## Passos de Instalação

# **1. configurar nomes de host:**
```bash
sudo hostnamectl set-hostname "master-node"
```
Caso queira ver o efeito imediato na troca do nome podem executar o seguinte comando:

```bash
exec bash
```
# **2. Disabilite swap do servidor:**

Esse comando desativa temporariamente a troca em seu sistema, ao reiniciar ele volta a swap para habilitado novamente:

```bash
sudo swapoff -a
```
Esse proximo comando modifica o arquivo de configuração para manter a troca desativada mesmo após a reinicialização do sistema.
```bash
sudo sed -i '/^\/swap/ s/^/#/' /etc/fstab
```
# **3. Configurar IPV4 bridge:**

```bash
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# sysctl params required by setup, params persist across reboots
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Apply sysctl params without reboot
sudo sysctl --system

```

# **4. Intale o kubelet, kubeadm e kubectl:**

Garanta que o indice de pacotes estejam atualizados:
```bash
sudo apt update
```
Agora faça a instalação dos seguintes pacotes:

```bash
sudo apt-get install -y apt-transport-https ca-certificates curl
```

Vamos buscar a chave pública do Google e armazená-la na pasta `/etc/apt/keyrings`. Essa chave é importante para verificar se os pacotes Kubernetes que baixamos são genuínos.

```bash
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-archive-keyring.gpg
```

Em seguida, precisamos informar ao gerenciador de pacotes apt onde encontrar os pacotes Kubernetes para download.

```bash
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
```

Após as etapas passar por essas etapas, precisaremos novamente atualizar os indices do gerenciador de pacote do ubuntu:
```bash
sudo apt update
```

Agora está tudo pronto para instalarmos os pacotes do kubernetes:
```bash
sudo apt install -y kubelet=1.26.5-00 kubeadm=1.26.5-00 kubectl=1.26.5-00
```

# **5. Instale o conteinerd.io:**

Configure os repositorios do Docker "apt" para poder dar continuidade na instalação do conteinerd.io

```bash
# Add Docker's official GPG key:
sudo apt-get update
sudo apt-get install ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
```

Agora instale o conteinerd.io:

```bash
 sudo apt install containerd.io
```
No caso do conteinerd.io precisaremos de configurar o CNI. Vou deixar as etapas e versões nos comandos abaixo, mas caso precisem de mais informações podem seguir a documentação disponível no [link de instruções de instalação do conteinerd.io](https://github.com/containerd/containerd/blob/main/docs/getting-started.md):

```bash
#baixando e configurando a versão 1.4.0 (latest na data de criação do documento)
wget https://github.com/containernetworking/plugins/releases/download/v1.4.0/cni-plugins-linux-amd64-v1.4.0.tgz

mkdir -p /opt/cni/bin

sudo tar Cxzvf /opt/cni/bin cni-plugins-linux-amd64-v1.4.0.tgz

```

Agora vamos configurar o containerd:

Primeiro utilize a configuração default para configurar o arquivo `/etc/containerd/config.toml`:

```bash
 sudo sh -c "containerd config default > /etc/containerd/config.toml"
```
Agora precisaramos modificar o arquivo config.toml para localizar a entrada que define "SystemdCgroup" como false e alterar seu valor para true:
```bash
sudo sed -i 's/ SystemdCgroup = false/ SystemdCgroup = true/' /etc/containerd/config.toml
```

Em seguida, reinicie os serviços containerd e kubelet para aplicar as alterações:

```bash
sudo systemctl restart containerd.service 
```

```bash
sudo systemctl restart kubelet.service
```

Caso queira deixar para que o kubelet suba automático ao iniciar o server, execute o seguinte comando:
```bash
sudo systemctl enable kubelet.service
```
# **6. inicializar o cluster Kubernetes:**

Ao inicializar um plano de controle do Kubernetes usando kubeadm, vários componentes são implantados para gerenciar e orquestrar o cluster. Alguns exemplos desses componentes são kube-apiserver, kube-controller-manager, kube-scheduler, etcd, kube-proxy. 'Precisamos baixar as imagens desses componentes executando o seguinte comando.

```bash
sudo kubeadm config images pull
```
Em seguida, inicialize seu nó master. O sinalizador --pod-network-cidr está configurando o intervalo de endereços IP para a rede do pod.

```bash
sudo kubeadm init --pod-network-cidr=10.10.0.0/16
```

para gerenciar o cluster, você deve configurar o kubectl no nó mestre. Crie o diretório .kube em sua pasta inicial e copie a configuração administrativa do cluster para seu diretório .kube pessoal. Em seguida, altere a propriedade do arquivo de configuração copiado para dar ao usuário permissão para usar o arquivo de configuração para interagir com o cluster.



```bash
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

# **6. Instale o plugin de rede :**
Nessa parte pode notar ao rodar o comando `kubectl get nodes` que o node master ainda está com o status de not ready. Para resolver isso precisamos de instalar o pluguin de rede.
Esse irá prover a comunicação entre os PODS. nesse tutorial resolvemos trabalhar com o Wave. Para instalar execute o seguinte comando:

```bash
kubectl apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml
```
