#!/bin/bash

read -p 'Name: ' namevar
echo $namevar
echo "Enter your Falcon CID"
read FALCON_CID
echo "Enter your Client ID"
read FALCON_CLIENT_ID
echo "Enter your Client Secret"
read FALCON_CLIENT_SECRET
echo "Enter your Falcon Cloud"
read FALCON_CLOUD

echo "$FALCON_CID"
echo "$FALCON_CLIENT_ID"
echo "$FALCON_CLIENT_SECRET"
echo "$FALCON_CLOUD"


export FALCON_CLOUD_API=api.crowdstrike.com
export FALCON_CONTAINER_VERSION="6.30.0-1301"
