# Lets remove any docker installations - if any
sudo apt-get remove docker docker-engine docker.io containerd runc

# Update and install packages to use a repository over HTTPS
sudo apt-get update && sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Add Docker's GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
sudo gpg --dearmor -o \
/usr/share/keyrings/docker-archive-keyring.gpg

# Setup the stable repository
echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt-get update && sudo apt-get install -y \
docker-ce docker-ce-cli containerd.io

# Configure the groups for Docker
sudo usermod -a -G docker $USER
newgrp docker

# Test Docker
docker run hello-world
echo "You should have seen the Docker Hello World message... if not... something busted."

# Install microk8s
echo "Now we're going to install MicroK8s..."
sudo snap install microk8s --classic --channel=1.22/stable

# Add current user to K8s group
sudo usermod -a -G microk8s $USER
sudo chown -f -R $USER ~/.kube
newgrp microk8s

# Wait k8s to be ready
microk8s status --wait-ready
echo "You should see a message saying K8's is running..."

# Configure the microK8s network
microk8s enable dns registry istio

# Setup alias for Kubtectl
echo -e "\nalias kubectl='microk8s kubectl'" >> ~/.bash_aliases
source ~/.bash_aliases

# Setup Kubeconfig file
cd $HOME
mkdir -p .kube
cd .kube
microk8s config > config
cd ..

# Let's test some K8s commands
kubectl get nodes
echo "You should see the current node listed above"
kubectl get pods
echo "There shouldn't be any pods yet..."
