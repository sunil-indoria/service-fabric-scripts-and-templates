#!/bin/bash

#
# Usage: sudo ./deploy.sh
#

if [ "$EUID" -ne 0 ]; then
    echo Please run this script as root or using sudo
    exit
fi

ExitIfError()
{
    if [ $1 != 0 ]; then
        echo "$2" 1>&2
        exit -1
    fi
}

Distribution=`lsb_release -cs`
if [ "xenial" != "$Distribution" ]; then
    echo "Service Fabric is not supported on $Distribution"
    exit -1
fi

#
# Add the service fabric repo and dependents to the sources list.
# Also add the corresponding keys.
#
sh -c 'echo "deb [arch=amd64] http://apt-mo.trafficmanager.net/repos/servicefabric/ trusty main" > /etc/apt/sources.list.d/servicefabric.list'
ExitIfError $?  "Error@$LINENO: Could not add Service Fabric repo to sources."

sh -c 'echo "deb [arch=amd64] https://apt-mo.trafficmanager.net/repos/dotnet-release/ xenial main" > /etc/apt/sources.list.d/dotnetdev.list'
ExitIfError $?  "Error@$LINENO: Could not add Dotnet repo to sources."

apt-key adv --keyserver apt-mo.trafficmanager.net --recv-keys 417A0893
ExitIfError $?  "Error@$LINENO: Failed to add key for Service Fabric repo"
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 417A0893
ExitIfError $?  "Error@$LINENO: Failed to add key for dotnet repo"

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
ExitIfError $?  "Error@$LINENO: Failed to add key for docker repo"

add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
ExitIfError $?  "Error@$LINENO: Failed to add Docker repo to sources."

apt-get update


#
# Install Service Fabric SDK and run the setup script
#

echo "servicefabric servicefabric/accepted-eula-v1 select true" | debconf-set-selections
echo "servicefabricsdkcommon servicefabricsdkcommon/accepted-eula-v1 select true" | debconf-set-selections

apt-get install servicefabricsdkcommon -f -y
ExitIfError $?  "Error@$LINENO: Failed to install Service Fabric SDK"

/opt/microsoft/sdk/servicefabric/common/sdkcommonsetup.sh
ExitIfError $?  "Error@$LINENO: Service Fabric common SDK setup failed."

export NODE_PATH=$NODE_PATH:$HOME/.node/lib/node_modules

if [ "$EUID" == "0" ]; then
    export NODE_PATH=$NODE_PATH:/root/.node/lib/node_modules
fi


#
# Setup XPlat Service Fabric CLI
#

git clone https://github.com/Azure/azure-xplat-cli.git

pushd "azure-xplat-cli"
npm install

ExitIfError $?  "Error@$LINENO: Failed to install XPlat Service Fabric CLI"

ln -s $(pwd)/bin/azure /usr/bin/azure

popd

azure --completion >> ~/azure.completion.sh
echo 'source ~/azure.completion.sh' >> ~/.bash_profile
source ~/azure.completion.sh

echo "Successfully completed Service Fabric SDK installation and setup."