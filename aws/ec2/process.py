import boto3
import datetime
import os
import json


def log_msg(level, message):
  timestamp = datetime.datetime.now()
  print(f'[{level}] {message} ({timestamp})')

def fetch_secrets():
    secret_name = "rubian/dockerhub_creds_2"

    # Create a Secrets Manager client
    session = boto3.session.Session()
    client = session.client(
        service_name='secretsmanager',
        region_name="us-east-1"
    )
    get_secret_value_response = client.get_secret_value(
        SecretId=secret_name
    )

    if 'SecretString' in get_secret_value_response:
        secret = get_secret_value_response['SecretString']
        return json.loads(secret)
    else:
      # TODO - log to cloudwatch
      log_msg("ERROR", "Unable to fetch secrets")

def create_container(minor_version, major_version):
  image_tag = f'mwdomino/rubian-test:{minor_version}'

  log_msg("INFO", f'Begin build {minor_version}')
  os.system(f'docker build -t {image_tag} --build-arg MAJOR_VERSION={major_version} --build-arg MINOR_VERSION={minor_version} {dockerfile_url}')

  log_msg("INFO", f'Begin push {minor_version}')
  os.system(f'docker image push {image_tag}')

  log_msg("INFO", f'Begin cleanup {minor_version}')
  os.system(f'docker image rm {image_tag}')

  log_msg("INFO", f'Complete {minor_version}')

def get_queue_url():
  queue_name = "rubian_build_queue"
  sqs_client = boto3.client("sqs", region_name="us-east-1")
  response = sqs_client.get_queue_url(
      QueueName=queue_name,
  )
  return response["QueueUrl"]

creds = fetch_secrets()
username = creds['username']
password = creds['password']
dockerfile_url = "https://raw.githubusercontent.com/mwdomino/rubian/master/Dockerfile"
os.system(f'docker login -u={username} -p={password} > /dev/null')
queue_url = get_queue_url()

client = boto3.client('sqs', region_name="us-east-1")

while True:
    messages = client.receive_message(QueueUrl=queue_url,MaxNumberOfMessages=1,WaitTimeSeconds=10)
    if 'Messages' in messages:
        for message in messages['Messages']:
            payload = json.loads(message['Body'])
            major = payload['major_version']
            minor = payload['minor_version']
            create_container(minor, major)
            client.delete_message(QueueUrl=queue_url,ReceiptHandle=message['ReceiptHandle'])
    else:
        print('Queue is empty')
        os.system('shutdown -P now')
        break
