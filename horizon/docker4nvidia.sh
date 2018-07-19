sudo apt update -y
sudo apt upgrade -y
# tools
sudo apt install -y tcsh curl jq ssh git unity-tweak-tool
# git
git config --global user.email "github@dcmartin.com"
git config --global user.name "dcmartin"

# driver
NVIDIA=$(lspci | grep -i nvidia)
if [ -z "${NVIDIA}" ]; then
  echo "no nvidia card"
  exit
fi

# bash ~/Downloads/NVIDIA-Linux-x86_64-384.98.run 
# cudnn-9.0-linux-x64-v7.tgz

if [ -z "~/Downloads/cuda-repo-ubuntu1604-9-0-local_9.0.176-1_amd64.deb" ]; then
  curl https://developer.nvidia.com/compute/cuda/9.0/Prod/local_installers/cuda-repo-ubuntu1604-9-0-local_9.0.176-1_amd64-deb -o ~/Downloads/cuda-repo-ubuntu1604-9-0-local_9.0.176-1_amd64.deb
fi
sudo dpkg --install ~/Downloads/cuda-repo-ubuntu1604-9-0-local_9.0.176-1_amd64.deb
sudo apt-key add /var/cuda-repo-9-0-local/7fa2af80.pub

sudo dpkg --install ~/Downloads/nccl-repo-ubuntu1604-2.1.2-ga-cuda9.0_1-1_amd64.deb
sudo dpkg --install ~/Downloads/nv-tensorrt-repo-ubuntu1604-ga-cuda9.0-trt3.0-20171128_1-1_amd64.deb

sudo apt-get update
sudo apt-get install -y cuda

## kitematic
sudo dpkg --install ~/Downloads/Kitematic_0.17.3_amd64.deb

curl -s -L https://nvidia.github.io/nvidia-container-runtime/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-container-runtime/ubuntu16.04/amd64/nvidia-container-runtime.list | sudo tee /etc/apt/sources.list.d/nvidia-container-runtime.list
sudo apt-get update

##
## DOCKER
##

sudo apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

sudo apt-get update

sudo apt-get install -y docker-ce

##
## NVIDIA DOCKER RUN-TIME
##
sudo apt-get install nvidia-container-runtime

if [ -z "/etc/systemd/system/docker.service.d" ]; then
  sudo mkdir -p /etc/systemd/system/docker.service.d
  sudo tee /etc/systemd/system/docker.service.d/override.conf <<EOF
[Service]
ExecStart=
ExecStart=/usr/bin/dockerd --host=fd:// --add-runtime=nvidia=/usr/bin/nvidia-container-runtime
EOF
  sudo systemctl daemon-reload
  sudo systemctl restart docker
fi

