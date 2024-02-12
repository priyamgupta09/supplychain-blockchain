#Steps on EC2 instance before creating BCN:
#1. Attach a full access role of AWSCLI to your IAM permissions
#2. make inbound rule for 30001-30004 for tcp for all ip(check if a particular IP can be specified)
	#https://docs.aws.amazon.com/managed-blockchain/latest/managementguide/managed-blockchain-security-sgs.html
#3. VPC and security group for EC2 and BCN should be same

echo Pre-requisities
echo installing jq
sudo yum -y install jq

echo Updating AWS CLI to the latest version
echo installing pip
curl -o get-pip.py https://bootstrap.pypa.io/get-pip.py
sudo python get-pip.py
sudo pip install awscli --upgrade

NETWORKNAME="Healthcare"
MEMBERNAME="org1"
ADMINUSERNAME="AdminUser"
ADMINPASSWORD="Password123"

aws managedblockchain create-network \
--network-configuration '{"Name":"${NETWORKNAME}", \
"Description":"HealthcareNetworkDescription", \
"Framework":"HYPERLEDGER_FABRIC","FrameworkVersion": "1.2", \
"FrameworkConfiguration": {"Fabric": {"Edition": "STARTER"}}, \
"VotingPolicy": {"ApprovalThresholdPolicy": {"ThresholdPercentage": 50, \
"ProposalDurationInHours": 24, \
"ThresholdComparator": "GREATER_THAN"}}}' \
--member-configuration '{"Name":"${MEMBERNAME}", \
"Description":"Org1 first member of network",\
"FrameworkConfiguration":{"Fabric":{"AdminUsername":"${ADMINUSERNAME}","AdminPassword":"${ADMINPASSWORD}"}}}'

#store the network and member id from the result
#wait for the network to become active
#to confirm creation use the below command
aws managedblockchain list-networks

NETWORKID=""
MEMBERID=""

#create a VPC Endpoint using Blockchain network console
#1. Open the Managed Blockchain console at https://console.aws.amazon.com/managedblockchain/.
#2. Choose Networks, select your network from the list, and then choose View details.
#3. Choose Create VPC endpoint.
#4. Choose a VPC.
#5. For Subnets, choose a subnet from the list, and then choose additional subnets as necessary.
#6. For Security groups, choose an EC2 security group from the list, and then choose additional security groups as necessary. We recommend that you select the same security group that your framework client EC2 instance is associated with.
#7. Choose Create.

ORDERINGSERVICEENDPOINT=""
VPCENDPOINTSERVICENAME=""

aws managedblockchain get-member --network-id $NETWORKID --member-id $MEMBERID

CASERVICEENDPOINT=""


#install utilities, docker, configure docker
sudo yum update -y
sudo yum install -y telnet
sudo yum -y install emacs
sudo yum install -y docker
sudo service docker start
sudo usermod -a -G docker ec2-user

#install docker compose
sudo curl -L https://github.com/docker/compose/releases/download/1.20.0/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
sudo chmod a+x /usr/local/bin/docker-compose
sudo yum install libtool -y

## Install golang.  
wget https://dl.google.com/go/go1.10.3.linux-amd64.tar.gz
tar -xzf go1.10.3.linux-amd64.tar.gz
sudo mv go /usr/local
sudo yum install libtool-ltdl-devel -y
sudo yum install git -y

## Make changes to the bash_profile here ##just copy paste the highlighted part
# .bash_profile

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
    . ~/.bashrc
fi

# User specific environment and startup programs
PATH=$PATH:$HOME/.local/bin:$HOME/bin

# GOROOT is the location where Go package is installed on your system
export GOROOT=/usr/local/go

# GOPATH is the location of your work directory
export GOPATH=$HOME/go

# Update PATH so that you can access the go binary system wide
export PATH=$GOROOT/bin:$PATH
export PATH=$PATH:/home/ec2-user/go/src/github.com/hyperledger/fabric-ca/bin

#apply the changes in .bash_profile
source ~/.bash_profile

#verify the Docker version
#Docker–17.06.2-ce or later
#Docker-compose–1.14.0 or later
#Go–1.10.x

sudo docker version
sudo /usr/local/bin/docker-compose version
go version

#set up the Hyperledger Fabric CA Client
#Verify the connectivity to VPC endpoint configured for the Fabric CA client
echo $CASERVICEENDPOINT
curl https://$CASERVICEENDPOINT/cainfo -k
telnet CaEndpoint-Without-Port CaPort

#configure CA Client
echo configure CA Client
mkdir -p /home/ec2-user/go/src/github.com/hyperledger/fabric-ca
cd /home/ec2-user/go/src/github.com/hyperledger/fabric-ca
wget https://github.com/hyperledger/fabric-ca/releases/download/v1.2.1/hyperledger-fabric-ca-linux-amd64-1.2.1.tar.gz
tar -xzf hyperledger-fabric-ca-linux-amd64-1.2.1.tar.gz

#Clone the Samples Repository
cd /home/ec2-user
git clone --branch v1.2.0 https://github.com/hyperledger/fabric-samples.git 

#Configure and Run Docker Compose to Start the Hyperledger Fabric CLI
#Use a text editor to create a configuration file for Docker Compose named docker-compose-cli.yaml in the /home/ec2-user directory, which you use to run the Hyperledger Fabric CLI.

#to start the Hyperledger Fabric peer CLI container
# move the docker-compose-cli.yaml file into home/ec2-user
echo start the Hyperledger Fabric peer CLI container
docker-compose -f docker-compose-cli.yaml up -d

#Enroll an Admin User
echo creating certification file
aws s3 cp s3://us-east-1.managedblockchain/etc/managedblockchain-tls-chain.pem  /home/ec2-user/managedblockchain-tls-chain.pem

#to check the contents of the file
#openssl x509 -noout -text -in /home/ec2-user/managedblockchain-tls-chain.pem

echo enrolling user
fabric-ca-client enroll -u https://$ADMINUSERNAME:$ADMINPASSWORD@$CASERVICEENDPOINT --tls.certfiles /home/ec2-user/managedblockchain-tls-chain.pem -M /home/ec2-user/admin-msp

cp -r admin-msp/signcerts admin-msp/admincerts

echo creating peer node
aws managedblockchain create-node \
--node-configuration '{"InstanceType":"bc.t3.small","AvailabilityZone":"us-east-1a"}' \
--network-id $NETWORKID \
--member-id $MEMBERID

#move the channel configuration file to home/ec2-user cd ~ after replacing the memberid at 2 places
docker exec cli configtxgen \
-outputCreateChannelTx /opt/home/mychannel.pb \
-profile OneOrgChannel -channelID mychannel \
--configPath /opt/home/

#setting up some environment variables

echo Use these commands to get the properties for setting up EnvVar

aws managedblockchain list-members
aws managedblockchain get-network
aws managedblockchain get-node

export MSP_PATH=/opt/home/admin-msp
export MSP=m-GOCYZCCH2VEJNBZHLE2DPQXRTE
export ORDERER=orderer.n-x462hqgxwvg57m6eu5nkcyoz3a.managedblockchain.us-east-1.amazonaws.com:30001
export PEER=nd-dfwpuntkhrcpjmv63vki4ezfsm.m-gocyzcch2vejnbzhle2dpqxrte.n-x462hqgxwvg57m6eu5nkcyoz3a.managedblockchain.us-east-1.amazonaws.com:30003

#These variables must be exported each time you log out of the client. To persist the variables across sessions, add the export statement to your ~/.bash_profile

# open .bash_profile and add these in the last
...other configurations
export MSP_PATH=/opt/home/admin-msp
export MSP=MemberID
export ORDERER=OrderingServiceEndpoint
export PEER=PeerNodeEndpoint
export CHAINCODENAME=healthcare1
export CHANNEL=mychannel

echo apply the changes to bash_profile
$source ~/.bash_profile

#channel creation

CHANNELNAME="mychannel"

echo creating a channel
docker exec -e "CORE_PEER_TLS_ENABLED=true" \
-e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/home/managedblockchain-tls-chain.pem" \
-e "CORE_PEER_ADDRESS=$PEER" \
-e "CORE_PEER_LOCALMSPID=$MSP" \
-e "CORE_PEER_MSPCONFIGPATH=$MSP_PATH" \
cli peer channel create -c mychannel \
-f /opt/home/mychannel.pb -o $ORDERER \
--cafile /opt/home/managedblockchain-tls-chain.pem --tls

#join peer node to channel

docker exec -e "CORE_PEER_TLS_ENABLED=true" \
-e "CORE_PEER_TLS_ROOTCERT_FILE=/opt/home/managedblockchain-tls-chain.pem" \
-e "CORE_PEER_ADDRESS=$PEER" \
-e "CORE_PEER_LOCALMSPID=$MSP" \
-e "CORE_PEER_MSPCONFIGPATH=$MSP_PATH" \
cli peer channel join -b mychannel.block \
-o $ORDERER --cafile /opt/home/managedblockchain-tls-chain.pem --tls

#install and instantiate the chaincode