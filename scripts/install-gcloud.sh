#!/bin/bash
VERSION=${1:-"448.0.0"}
curl -#O https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-$VERSION-linux-x86_64.tar.gz
tar -xf google-cloud-cli-$VERSION-linux-x86_64.tar.gz
./google-cloud-sdk/install.sh
./google-cloud-sdk/bin/gcloud init
