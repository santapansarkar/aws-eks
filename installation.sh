#!/bin/bash

curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp

sudo mv -v /tmp/eksctl /usr/local/bin

#auto completion command
eksctl completion bash >> ~/.bash_completion
. /etc/profile.d/bash_completion.sh
. ~/.bash_completion

# create an IAM role for EC2 SErvice with ADministrator Permission
#create KMS keys for EKS cluster to use when encrypting Kubernetes secrets
aws kms create-alias --alias-name alias/k8-eks --target-key-id $(aws kms create-key --query KeyMetadata.Arn --output text)
#Verify the KMS keys
aws kms list-keys --query Keys[*][KeyId] --output text|xargs aws kms describe-key --key-id
aws kms describe-key --key-id $(aws kms list-keys --query Keys[*][KeyId] --output text)
#Let’s retrieve the ARN of the CMK to input into the create cluster command
export MASTER_ARN=$(aws kms describe-key --key-id alias/k8-eks --query KeyMetadata.Arn --output text)
echo "export MASTER_ARN=${MASTER_ARN}" | tee -a ~/.bash_profile

cat << EOF > k8-eks-eksctl.yaml
---
kind: ClusterConfig
apiVersion: eksctl.io/v1alpha5
metadata:
  name: k8-eks-eksctl
  region: us-east-1
  version: "1.19"
vpc:
  id: "vpc-cf1284b2"
  subnets: 
    public: 
      us-east-1a:
        id: "subnet-f90015b4"
      us-east-1b:
        id: "subnet-db387e84"  
nodeGroups:
  - name: eks-web-ng
    amiFamily: AmazonLinux2            
    instanceType: t2.micro
    desiredCapacity: 1
    minSize: 0
    maxSize: 1
    ssh:
      allow: true
      publicKeyName: us-east-1-KP
      enableSsm: true
    tags: 
      Name : eks-eksctl 
secretsEncryption:
  # ARN of the KMS key
  keyARN: arn:aws:kms:us-east-1:350102312519:key/dbb1b83e-d37b-4fb0-acca-c56d4f314b34  
EOF

#run create cluster command 
eksctl create cluster -f k8-eks-eksctl.yaml

#verify cluster
kubectl get nodes

#fetch Role_name and put it into env variable
STACK_NAME=$(eksctl get nodegroup --cluster k8-eks-eksctl -o json | jq -r '.[].StackName')
ROLE_NAME=$(aws cloudformation describe-stack-resources --stack-name $STACK_NAME | jq -r '.StackResources[] | select(.ResourceType=="AWS::IAM::Role") | .PhysicalResourceId')
echo "export ROLE_NAME=${ROLE_NAME}" | tee -a ~/.bash_profile

#deploy kubernetes dashboard
export DASHBOARD_VERSION="v2.0.0"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/${DASHBOARD_VERSION}/aio/deploy/recommended.yaml
kubectl proxy --port=8080 --address=0.0.0.0 --disable-filter=true &

#get auth token to login to dashboard
aws eks get-token --cluster-name eksworkshop-eksctl | jq -r '.status.token'






