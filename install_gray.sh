#!/bin/bash

#graylog_pass=admin
# http_ip=
# td_agent_file=



#tcp_ports= "80 443 8080"
#upd_ports=

yum install epel-release -y 
yum update -y 
yum install net-tools  -y 
yum install pwgen -y

echo "[mongodb-org-4.0]
name=MongoDB Repository
baseurl=https://repo.mongodb.org/yum/redhat/$releasever/mongodb-org/4.0/x86_64/
gpgcheck=1
enabled=1
gpgkey=https://www.mongodb.org/static/pgp/server-4.0.asc
" > /etc/yum.repos.d/mongodb-org.repo

yum install mongodb-org -y 

systemctl daemon-reload
systemctl enable mongod.service
systemctl start mongod.service
systemctl --type=service --state=active | grep mongod
rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch

echo "[elasticsearch-6.x]
name=Elasticsearch repository for 6.x packages
baseurl=https://artifacts.elastic.co/packages/oss-6.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md" > /etc/yum.repos.d/elasticsearch.repo" > /etc/yum.repos.d/elasticsearch.repo
yum install elasticsearch-oss -y 

cp /etc/elasticsearch/elasticsearch.yml /etc/elasticsearch/elasticsearch.yml.bak

sed 's/^cluster\.name.*/cluster\.name graylog/' /etc/elasticsearch/elasticsearch.yml > /etc/elasticsearch/elasticsearch.yml


echo "action.auto_create_index: false" >> /etc/elasticsearch/elasticsearch.yml 

systemctl daemon-reload



systemctl enable elasticsearch.service

systemctl restart elasticsearch.service

rpm -Uvh https://packages.graylog2.org/repo/packages/graylog-3.2-repository_latest.rpm

yum install -y  graylog-server 

cp /etc/graylog/server/server.conf /etc/graylog/server/server.conf.bak

gray_hash$(echo -n "$graylog_pass"|sha256sum | cut -d" " -f1)

sed "s/^root_password_sha2.*/root_password_sha2=$gray_hash/" /etc/graylog/server/server.conf > /etc/graylog/server/server.conf

pwgen_hash=$(pwgen -N 1 -s 96)

sed "s/^.password_secret.*/password_secret=$pwgen_hash/" /etc/graylog/server/server.conf > /etc/graylog/server/server.conf




sed "s/^http_bind_address.*/http_bind_address=$http_ip/" /etc/graylog/server/server.conf > /etc/graylog/server/server.conf


systemctl daemon-reload
systemctl enable graylog-server.service
systemctl start graylog-server.service


#Firewall Rules

firewall-cmd --zone=public --add-port=9000/tcp --permanent

firewall-cmd --reload


setsebool -P httpd_can_network_connect 1

semanage port -a -t http_port_t -p tcp 9000

semanage port -a -t http_port_t -p tcp 9200

semanage port -a -t mongod_port_t -p tcp 27017


### Graylog Kurulumu Tamalandi ###


curl -L https://toolbelt.treasuredata.com/sh/install-redhat-td-agent3.sh | sh

systemctl daemon-reload 

systemctl enable td-agent

cp $td_agent_file /etc/td-agent/td-agent.conf

td-agent-gem install fluent-plugin-multi-format-parser
td-agent-gem install fluent-plugin-gelf-hs
td-agent-gem install fluent-plugin-record-modifier --no-document


### Firewall Rules ##

for i in $tcp_ports;
do
firewall-cmd --zone=public --add-port=$i/tcp --permanent;
done

for i in $udp_ports;
do
firewall-cmd --zone=public --add-port=$i/upd --permanent;
done

firewall-cmd --reload

systemctl restart td-agent

echo "DONE"

