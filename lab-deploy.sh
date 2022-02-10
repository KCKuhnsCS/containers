#!/bin/bash

#####################################
######### DOCKER DEPLOYMENT #########
#####################################


read -t 5 -p "Deploying Docker, MicroK8s and Falcon Container sensor..."
clear
read -t 5 -p "Removing any old Docker configurations..."
sudo apt-get remove docker docker-engine docker.io containerd runc
clear
read -t 5 -p "Installing packages to use repositories over HTTPS..."
sudo apt-get update && sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release
clear
read -t 5 -p "Configuring Docker repository..."
sudo rm /usr/share/keyrings/docker-archive-keyring.gpg
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
sudo gpg --dearmor -o \
/usr/share/keyrings/docker-archive-keyring.gpg
echo \
  "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
clear
read -t 5 -p "Installing and configuring Docker..."
sudo apt-get update && sudo apt-get install -y \
docker-ce docker-ce-cli containerd.io
sudo usermod -a -G docker $USER
clear
read -t 5 -p "Running a test container...
"
docker run hello-world
read -t 5 -p "You should see the welcome message from Docker above."
clear
#######################################
######### MICROK8s DEPLOYMENT #########
#######################################

read -t 5 -p "Installing and configuring MicroK8s..."

for i in 1 2 3 4 5; do sudo snap install microk8s --classic --channel=1.22/stable && break || sleep 15; done

sudo usermod -a -G microk8s $USER
sudo chown -f -R $USER ~/.kube
#newgrp microk8s
clear
read -t 5 -p "Preparing MicroK8s for use...
"
sudo microk8s status --wait-ready
read -t 5 -p "You should see that MicroK8s is running above."
clear
read -t 5 -p "Next we'll configure some resources and permissions for MicroK8s to function.
"
microk8s enable dns registry istio
clear
microk8s kubectl get nodes
read -t 5 -p "You should see your node for K8s listed above."
clear

##############################################
######### FALCON INJECTOR DEPLOYMENT #########
##############################################

read -t 5 -p "Installing Python and dependencies for Docker API."
sudo apt install -y python3-pip
pip install requests docker
clear
read -p "
For this next section, you'll need a valid API key to download the sensor via API.

1. In the Falcon console, go to Support > API Clients and Keys. 
2. Click Add new API client. 
3. For the Falcon Images Download option in the list, select Read. 
4. Click Add and note the Client ID and Client Secret. 

PRESS ENTER WHEN READY TO CONTINUE...

"
clear
echo "Enter your Falcon CID"
read FALCON_CID
clear
echo "Enter your Client ID"
read FALCON_CLIENT_ID
clear
echo "Enter your Client Secret"
read FALCON_CLIENT_SECRET
clear
echo "Enter your Falcon Cloud (US-1, US-2, EU-1, etc."
read FALCON_CLOUD
export FALCON_CLOUD_API=api.crowdstrike.com
export FALCON_CONTAINER_VERSION="6.30.0-1301"
export FALCON_CLOUD_LOWER="$(echo $FALCON_CLOUD | tr [[:upper:]] [[:lower:]])"
FALCON_ART_USERNAME="fc-$(echo $FALCON_CID | tr [[:upper:]] [[:lower:]] | cut -d'-' -f1)"
clear
read -t 5 -p "Generating a bearer token for API authentication...
"
FALCON_API_BEARER_TOKEN=$(curl \
--silent \
--header "Content-Type: application/x-www-form-urlencoded" \
--data "client_id=${FALCON_CLIENT_ID}&client_secret=${FALCON_CLIENT_SECRET}" \
--request POST \
--url "https://$FALCON_CLOUD_API/oauth2/token" | \
python3 -c "import sys, json; print(json.load(sys.stdin)['access_token'])")
clear
read -t 5 -p "Using the bearer token to authenticate to the CrowdStrike registry..."
FALCON_ART_PASSWORD=$(curl --silent -X GET -H "authorization: Bearer ${FALCON_API_BEARER_TOKEN}" \
https://${FALCON_CLOUD_API}/container-security/entities/image-registry-credentials/v1 | \
python3 -c "import sys, json; print(json.load(sys.stdin)['resources'][0]['token'])")
sudo docker login --username $FALCON_ART_USERNAME --password $FALCON_ART_PASSWORD registry.crowdstrike.com
clear
export FALCON_IMAGE_PULL_TOKEN=$(sudo cat /root/.docker/config.json | base64 -w 0)
export FALCON_IMAGE_URI=registry.crowdstrike.com/falcon-container/${FALCON_CLOUD_LOWER}/release/falcon-sensor:${FALCON_CONTAINER_VERSION}.container.x86_64.Release.${FALCON_CLOUD}
read -t 5 -p 'Creating a new namespace called "falconlab"'
microk8s kubectl create ns falconlab
export NAMESPACES=default,falconlab
clear
read -t 5 -p "Pulling the container image from CrowdStrike registry, generating a YAML file and passing it into K8s to execute..."
sudo docker run \
--rm $FALCON_IMAGE_URI \
-falconctl-env FALCONCTL_OPT_TAGS="VM,lab" \
-namespaces $NAMESPACES \
-cid $FALCON_CID \
-image $FALCON_IMAGE_URI \
-pulltoken "${FALCON_IMAGE_PULL_TOKEN}" \
-disable-default-ns-injection | \
tee falcon-container.yaml | \
sudo microk8s kubectl create -f -
clear
read -t 5 -p "Now we're going to enable the injector in our namespaces."
microk8s kubectl label namespace default sensor.falcon-system.crowdstrike.com/injection=enabled
microk8s kubectl label namespace falconlab sensor.falcon-system.crowdstrike.com/injection=enabled
microk8s kubectl rollout status deployment injector -n falcon-system
microk8s kubectl get pods -n falcon-system
read -t 5 -p "You should see the Falcon injector listed above."
clear
read -t 5 -p "Now let's deploy a vulnerable container to see if the injector applies properly. 
We can also test detections with our new container."
microk8s kubectl apply -f https://raw.githubusercontent.com/isimluk/vulnapp/master/vulnerable.example.yaml
microk8s kubectl describe service vulnerable-example-com
