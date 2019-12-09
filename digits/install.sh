#!/bin/csh -fb

# GIT
setenv GIT ~/GIT

# DIGITS
setenv DIGITS_ROOT "$GIT/digits"
setenv CUDA_DEB "cuda-repo-ubuntu1604_8.0.61-1_amd64.deb"
setenv ML_DEB "nvidia-machine-learning-repo-ubuntu1604_1.0.0-1_amd64.deb"

setenv CUDA_REPO_PKG "http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64/$CUDA_DEB"
setenv ML_REPO_PKG "http://developer.download.nvidia.com/compute/machine-learning/repos/ubuntu1604/x86_64/$ML_DEB"

if (! -e "$DIGITS_ROOT/$CUDA_DEB") then
  wget "$CUDA_REPO_PKG" -O $DIGITS_ROOT/$CUDA_DEB && sudo dpkg -i $DIGITS_ROOT/$CUDA_DEB
endif
if (! -e "$DIGITS_ROOT/$ML_DEB") then
  wget "$ML_REPO_PKG" -O $DIGITS_ROOT/$ML_DEB && sudo dpkg -i $DIGITS_ROOT/$ML_DEB
endif

sudo apt install -y --no-install-recommends git graphviz python-dev python-flask python-flaskext.wtf python-gevent python-h5py python-numpy python-pil python-pip python-scipy python-tk libprotobuf-dev protobuf-compiler
sudo -H pip install --upgrade pip
sudo -H pip install setuptools
sudo -H pip install -r $DIGITS_ROOT/requirements.txt
# CAFFE
sudo apt install -y --no-install-recommends build-essential cmake git gfortran libatlas-base-dev libboost-filesystem-dev libboost-python-dev libboost-system-dev libboost-thread-dev libgflags-dev libgoogle-glog-dev libhdf5-serial-dev libleveldb-dev liblmdb-dev libopencv-dev libsnappy-dev python-all-dev python-dev python-h5py python-matplotlib python-numpy python-opencv python-pil python-pip python-pydot python-scipy python-skimage python-sklearn

setenv CAFFE_ROOT "$GIT/caffe"
if (! -d "$CAFFE_ROOT") then
  mkdir -p "$CAFFE_ROOT"
  git clone https://github.com/NVIDIA/caffe.git $CAFFE_ROOT -b 'caffe-0.15'
else
  pushd "$CAFFE_ROOT"
  git pull
  popd
endif
# PREREQUISITES
sudo -H pip install -r $CAFFE_ROOT/python/requirements.txt
# cat $CAFFE_ROOT/python/requirements.txt | xargs -n1 sudo pip install

# BUILD
pushd $CAFFE_ROOT
mkdir build
cd build
cmake ..
make -j4
make install
popd

