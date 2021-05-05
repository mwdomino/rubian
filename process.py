import boto3
import datetime
import os
import json

#username = os.environ.get('DOCKER_HUB_USERNAME')
#password = os.environ.get('DOCKER_HUB_PASSWORD')

def log_msg(level, message):
  timestamp = datetime.datetime.now()
  print(f'[{level}] {message} ({timestamp})')

def create_container(minor_version, major_version):
  image_tag = f'mwdomino/rubian-test:{minor_version}'

  log_msg("INFO", f'Begin build {minor_version}')
  os.system(f'docker build -t {image_tag} --build-arg MAJOR_VERSION={major_version} --build-arg MINOR_VERSION={minor_version} {dockerfile_url}')

  log_msg("INFO", f'Begin push {minor_version}')
  os.system(f'docker image push {image_tag}')

  log_msg("INFO", f'Begin cleanup {minor_version}')
  os.system(f'docker image rm {image_tag}')

  log_msg("INFO", f'Complete {minor_version}')

username = "mwdomino"
password = "ynSXds2Fmn8U6P"
queue_name = "rubian_build_queue"
dockerfile_url = "https://raw.githubusercontent.com/mwdomino/rubian/master/Dockerfile"
os.system(f'docker login -u={username} -p={password} > /dev/null')

# Pull messages from SQS and do work
sqs_client = boto3.client('sqs', region_name="us-east-1")
response = sqs_client.receive_message(
    QueueUrl='https://sqs.us-east-1.amazonaws.com/634822239175/rubian_build_queue',
    MaxNumberOfMessages=1,
    WaitTimeSeconds=10,
)
print("Receiving")

for message in response.get('Messages', []):
    payload = json.loads(message['Body'])
    major = payload['major_version']
    minor = payload['minor_version']
    create_container(minor, major)
