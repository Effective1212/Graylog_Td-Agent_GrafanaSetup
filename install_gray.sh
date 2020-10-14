#!/bin/bash

############################ Declare Variables ############################

graylog_pass=kOa9aPmW
http_ip=192.168.48.180
td_agent_file="/root/td-agent.conf"

td_agent_plugins="/root/plugin/custom-plugins/"


tcp_ports=(80 9000 3000 11514 514 443 )
upd_ports=(601 514)


############################ STARTING INSTLATION ############################


yum update -y
yum install epel-release -y
yum install net-tools  -y
yum install pwgen wget sudo -y
yum install java-1.8.0-openjdk-headless.x86_64 -y
yum install policycoreutils-python -y


setenforce Permissive

echo -e "\e[0;44mUpdates Are Finissed!!!\e[0m"


###### Grafana Installation


echo -e "\e[0;44mStarting Installation of Grafana-Server\e[0m"

echo '[grafana]
name=grafana
baseurl=https://packages.grafana.com/oss/rpm
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://packages.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt' > /etc/yum.repos.d/grafana.repo


yum install grafana -y 

sudo systemctl daemon-reload
systemctl enable grafana-server
sudo systemctl start grafana-server



asd=$(systemctl --type=service --state=active | grep grafana)
echo -e "\e[0;44mGrafana-Server is\e[0m \e[0;43m$asd\e[0m"



echo -e "\e[e0;44mStarting Installation of MongoDB\e[0m"

echo '
[mongodb-org-4.2]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/$releasever/mongodb-org/4.2/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-4.2.asc' > /etc/yum.repos.d/mongodb-org.repo


yum install mongodb-org -y

systemctl daemon-reload
systemctl enable mongod.service
systemctl start mongod.service

asd=$(systemctl --type=service --state=active | grep mongod)

echo -e "\e[0;44mMongoDB is\e[0m \e[0;43m$asd\e[0m"

echo -e "\e[0;44mStarting Installation of elasticsearch\e[0m"

rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch

echo "[elasticsearch-6.x]
name=Elasticsearch repository for 6.x packages
baseurl=https://artifacts.elastic.co/packages/oss-6.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md" > /etc/yum.repos.d/elasticsearch.repo

yum install elasticsearch-oss -y

systemctl daemon-reload

systemctl enable elasticsearch.service

cp /etc/elasticsearch/elasticsearch.yml /etc/elasticsearch/elasticsearch.yml.bak

sed 's/^#cluster\.name.*/cluster\.name graylog/' /etc/elasticsearch/elasticsearch.yml.bak > /etc/elasticsearch/elasticsearch.yml

echo "action.auto_create_index: false" >> /etc/elasticsearch/elasticsearch.yml

systemctl restart elasticsearch.service

asd=$(systemctl --type=service --state=active | grep elasticsearch)

echo -e "\e[0;44mElasticsearch is \e[0m \e[0;43m$asd\e[0m"

echo -e "\e[0;44mStarting Installation of Graylog-Server\e[0m"

rpm -Uvh https://packages.graylog2.org/repo/packages/graylog-3.2-repository_latest.rpm

yum install -y  graylog-server

systemctl daemon-reload
systemctl enable graylog-server.service

cp /etc/graylog/server/server.conf /etc/graylog/server/server.conf.bak

gray_hash=$(echo -n "$graylog_pass"|sha256sum | cut -d" " -f1)

pwgen_hash=$(pwgen -N 1 -s 96)

sed "s/^root_password_sha2.*/root_password_sha2=$gray_hash/" /etc/graylog/server/server.conf.bak > /etc/graylog/server/server.conf
cp -f /etc/graylog/server/server.conf /etc/graylog/server/my.conf
sed "s/^password_secret.*/password_secret=$pwgen_hash/" /etc/graylog/server/my.conf > /etc/graylog/server/server.conf
cp -f /etc/graylog/server/server.conf /etc/graylog/server/my.conf
sed "s/^#http_bind_address.*/http_bind_address=$http_ip:9000/" /etc/graylog/server/my.conf > /etc/graylog/server/server.conf
rm -f /etc/graylog/server/my.conf

systemctl daemon-reload

systemctl start graylog-server.service


asd=$(systemctl --type=service --state=active | grep graylog)

echo -e "\e[0;44mGraylog-Server is \e[0m \e[0;43m$asd\e[0m"


#Firewall Rules

firewall-cmd --zone=public --add-port=9000/tcp --permanent

firewall-cmd --reload


setsebool -P httpd_can_network_connect 1

semanage port -a -t http_port_t -p tcp 9000

semanage port -a -t mongod_port_t -p tcp 3000



echo -e "\e[0;44mStarting Installation of Td-Agent\e[0m"

curl -L https://toolbelt.treasuredata.com/sh/install-redhat-td-agent3.sh|sh

systemctl daemon-reload

systemctl enable td-agent

if [ ${tcp_ports} ]
then
cp $td_agent_file /etc/td-agent/td-agent.conf
fi

echo -e "\e[0;44mTd-Agent Gem plugins are installing\e[0m"

td-agent-gem install fluent-plugin-multi-format-parser
td-agent-gem install fluent-plugin-gelf-hs
td-agent-gem install fluent-plugin-record-modifier --no-document

echo -e "\e[0;44mDone with Td-Agent Gem plugins installation\e[0m"

mkdir '/etc/td-agent/custom-plugins'

cp $td_agent_plugins /etc/td-agent/custom-plugins/

cp /etc/systemd/system/multi-user.target.wants/td-agent.service /root/td-agent.service 

sed "s/User=.*/User=root/ " /root/td-agent.service > /etc/systemd/system/multi-user.target.wants/td-agent.service

sed "s/Group=.*/Group=root/" /root/td-agent.service > /etc/systemd/system/multi-user.target.wants/td-agent.service

systemctl daemon-reload

systemctl restart td-agent
asd=$(systemctl --type=service --state=active | grep td-agent)

echo -e "\e[0;44mTd-Agent is \e[0m \e[0;43m$asd\e[0m"


### Firewall Rules ##

echo -e "\e[0;44mFirewalld rules are starting to generate\e[0m"


if [ ${tcp_ports} ]
then
for i in ${tcp_ports[@]}
do
firewall-cmd --zone=public --add-port=$i/tcp --permanent
done
fi


if [ ${udp_ports} ]
then
for i in ${udp_ports[@]}
do
firewall-cmd --zone=public --add-port=$i/udp --permanent
done
fi


systemctl daemon-reload

firewall-cmd --reload


echo -e "\e[0;43mDONE!!!!\e[0m"
