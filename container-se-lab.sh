read -p "This script will install and configure Docker and MicroK8s all at once. You'll also have an option to deploy Falcon Container Sensor after MicroK8s is configured...
Press any key to start."

# Lets remove any docker installations - if any
read -t 5 -p "First we'll check if Docker is installed and remove old versions.
Next we'll configure resources and permissions we need for Docker and install the new version."
echo
echo
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
echo
echo
read -t 5 -p "You should see the welcome message from Docker above..."
echo
echo


# Install microk8s
read -t 5 -p "Now we'll install MicroK8s..."
sudo snap install microk8s --classic --channel=1.22/stable

# Add current user to K8s group
sudo usermod -a -G microk8s $USER
sudo chown -f -R $USER ~/.kube
newgrp microk8s

# Wait k8s to be ready
microk8s status --wait-ready
echo
echo
read -t 5 -p "You should see that MicroK8s is running above.
Next we'll configure some resources and permissions for MicroK8s to function."

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
kubectl get pods
echo
echo
read -t 5 -p "Above you should see the K8s nodes
There should be no pods running."
