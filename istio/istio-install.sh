curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.24.2 sh -
cd istio-1.24.2
export PATH=$PWD/bin:$PATH
istioctl install --set profile=demo -y