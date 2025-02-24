#!/bin/bash

# Defina suas configurações de rede
INTERFACE="enp0s3"   # Substitua pelo nome correto da interface de rede
STATIC_IP="172.16.0.51/22" # IP fixo com máscara (ex: /24 para 255.255.255.0)
GATEWAY="172.16.0.1"
DNS="8.8.8.8, 8.8.4.4" # Servidores DNS
NEW_HOSTNAME="control-plane01" # Novo hostname

# Caminho do arquivo Netplan (verifique qual existe no seu sistema)
NETPLAN_FILE="/etc/netplan/50-cloud-init.yaml"

echo "Configurando IP fixo para $STATIC_IP na interface $INTERFACE..."
# Faz backup do arquivo original
cp $NETPLAN_FILE "$NETPLAN_FILE.bak"

# Escreve a nova configuração no arquivo Netplan
cat <<EOF | sudo tee $NETPLAN_FILE
network:
  version: 2
  renderer: networkd
  ethernets:
    $INTERFACE:
      dhcp4: no
      addresses:
        - $STATIC_IP
      routes:
        - to: 0.0.0.0/0
          via: $GATEWAY
      nameservers:
        addresses: [$DNS]
EOF

# Aplica a nova configuração de rede
sudo netplan apply

echo "Configuração de IP fixo aplicada com sucesso!"

# Alteração do hostname
echo "Alterando hostname para $NEW_HOSTNAME..."

# Define o novo hostname temporariamente
sudo hostnamectl set-hostname $NEW_HOSTNAME

# Atualiza o arquivo /etc/hostname
echo "$NEW_HOSTNAME" | sudo tee /etc/hostname

# Atualiza o arquivo /etc/hosts
sudo sed -i "s/^127.0.1.1.*/127.0.1.1 $NEW_HOSTNAME/" /etc/hosts
echo -e "$(echo $STATIC_IP | sed 's:/.*::') $NEW_HOSTNAME" | sudo tee -a /etc/hosts


echo "Hostname alterado para: $(hostname)"
sleep 5
sudo init 6
