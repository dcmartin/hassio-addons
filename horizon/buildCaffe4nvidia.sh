# For Ubuntu 16.04
CUDA_REPO_PKG=http://developer.download.nvidia.com/compute/cuda/repos/ubuntu1604/x86_64/cuda-repo-ubuntu1604_8.0.61-1_amd64.deb
ML_REPO_PKG=http://developer.download.nvidia.com/compute/machine-learning/repos/ubuntu1604/x86_64/nvidia-machine-learning-repo-ubuntu1604_1.0.0-1_amd64.deb

# Install repo packages
wget "$CUDA_REPO_PKG" -O /tmp/cuda-repo.deb && sudo dpkg -i /tmp/cuda-repo.deb && rm -f /tmp/cuda-repo.deb
wget "$ML_REPO_PKG" -O /tmp/ml-repo.deb && sudo dpkg -i /tmp/ml-repo.deb && rm -f /tmp/ml-repo.deb

# Download new list of packages
apt-get update

apt-get install -y --no-install-recommends git graphviz python-dev python-flask python-flaskext.wtf python-gevent python-h5py python-numpy python-pil python-pip python-scipy python-tk

##
## BUILD PROTOBUF
##
apt-get install -y autoconf automake libtool curl make g++ git python-dev python-setuptools unzip

# example location - can be customized
export PROTOBUF_ROOT=~/GIT/protobuf
git clone https://github.com/google/protobuf.git $PROTOBUF_ROOT -b '3.2.x'

cd $PROTOBUF_ROOT
./autogen.sh
./configure
make "-j$(nproc)"
make install
ldconfig
cd python
python setup.py install --cpp_implementation

## BUILD CAFFE

apt-get install -y --no-install-recommends build-essential cmake git gfortran libatlas-base-dev libboost-filesystem-dev libboost-python-dev libboost-system-dev libboost-thread-dev libgflags-dev libgoogle-glog-dev libhdf5-serial-dev libleveldb-dev liblmdb-dev libopencv-dev libsnappy-dev python-all-dev python-dev python-h5py python-matplotlib python-numpy python-opencv python-pil python-pip python-pydot python-scipy python-skimage python-sklearn

# example location - can be customized
export CAFFE_ROOT=~/GIT/caffe
git clone https://github.com/NVIDIA/caffe.git $CAFFE_ROOT -b 'caffe-0.15'

pip install -r $CAFFE_ROOT/python/requirements.txt

cd $CAFFE_ROOT
mkdir build
cd build
cmake ..
make -j"$(nproc)"
make install
