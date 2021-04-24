import boto3
import os
import requests

def get_digest():
  username = os.environ.get('DOCKER_HUB_USERNAME')
  password = os.environ.get('DOCKER_HUB_PASSWORD')
  headers = { "Accept": "application/vnd.docker.distribution.manifest.list.v2+json" }

  token = requests.get(
    'https://auth.docker.io/token?scope=repository:library/debian:pull&service=registry.docker.io',
    auth=(username, password),
    headers=headers).json()['token']

  if token:
    headers['Authorization'] = f'Bearer {token}'
    resp = requests.get("https://registry-1.docker.io/v2/library/debian/manifests/latest", headers=headers)
    digest = resp.headers['Docker-Content-Digest']

  return digest


def create_or_update_stored_sha(current_sha):
  bucket = os.environ.get('RUBIAN_BASE_BUCKET')
  current_sha = current_sha.strip()

  try:
    s3 = boto3.resource('s3')
    version_object = s3.Object(bucket, 'version')
    stored_sha = version_object.get()['Body'].read().decode('utf-8').strip()

    if stored_sha == current_sha:
      # TODO - log to cloudwatch
      print(f'SHA {current_sha} is still the most current image')
    else:
      # TODO - log to cloudwatch
      version_object.put(Body=current_sha)
  except:
    # TODO - log to cloudwatch
    version_object.put(Body=current_sha)

def handler(event, context):
  current_sha = get_digest()
  create_or_update_stored_sha(current_sha)
