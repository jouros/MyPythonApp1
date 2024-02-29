#!/bin/bash

# ./edit_charts.sh 1.0.4 0.0.4 konttirefeapi dkubernetesprojectcr.azurecr.io

chartVersion=$1
imageTag=$2
imageName=$3
registryServerName=$4
BuildSourceVersion=$5

echo "parameters from pipeline: $1 $2 $3 $4 $5"


cp -r /home/agentuser/helm_template/charts/projectName "/home/agentuser/helm_template/charts/$BuildSourceVersion" 

sed -i "s/^\(version:\).*/\1 $chartVersion/" "/home/agentuser/helm_template/charts/$BuildSourceVersion/Chart.yaml"
sed -i "s/^\(appVersion:\).*/\1 $imageTag/" "/home/agentuser/helm_template/charts/$BuildSourceVersion/Chart.yaml"
sed -i "s/^\(name:\).*/\1 $imageName/" "/home/agentuser/helm_template/charts/$BuildSourceVersion/Chart.yaml"
sed -i "s/\(tag:\).*/\1 \"$BuildSourceVersion\"/" "/home/agentuser/helm_template/charts/$BuildSourceVersion/values.yaml"
sed -i "s/\(repository:\).*/\1 $registryServerName\/$imageName/" "/home/agentuser/helm_template/charts/$BuildSourceVersion/values.yaml"
grep -rl 'test-nginx' "/home/agentuser/helm_template/charts/$BuildSourceVersion/templates/*" | xargs -r sed -i "s/test-nginx/$imageName/g"


#helm lint tänne
