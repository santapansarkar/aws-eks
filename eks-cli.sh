#!/bin/bash
aws eks list-clusters --query clusters[*]
eks_cluster_name=`aws eks list-clusters --query clusters[0]`
echo $eks_cluster_name
aws eks list-clusters --query clusters[0]|xargs aws eks describe-cluster --name


