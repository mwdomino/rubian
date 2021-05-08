#!/bin/bash
yum update
yum install -y docker
systemctl start docker
cd /root
wget https://raw.githubusercontent.com/mwdomino/rubian/master/aws/ec2/process.py
pip3 install boto3
python3 /root/sqs_processor.py
