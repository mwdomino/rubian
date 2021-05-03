import boto3
import json
import re
import requests

import env_vars as env

env = env.Environment()

def get_digest():
  headers = { "Accept": "application/vnd.docker.distribution.manifest.list.v2+json" }

  token = requests.get(
    'https://auth.docker.io/token?scope=repository:library/debian:pull&service=registry.docker.io',
    auth=(
        env.docker_hub_username,
        env.docker_hub_password
    ),
    headers=headers).json()['token']

  if token:
    headers['Authorization'] = f'Bearer {token}'
    resp = requests.get("https://registry-1.docker.io/v2/library/debian/manifests/latest", headers=headers)
    digest = resp.headers['Docker-Content-Digest']

  return digest


def create_or_update_stored_sha(current_sha):
  current_sha = current_sha.strip()

  try:
    s3 = boto3.resource('s3')
    version_object = s3.Object(env.rubian_base_bucket, 'version')
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

def base_image_checker_handler(event, context):
  current_sha = get_digest()
  create_or_update_stored_sha(current_sha)




MAJOR_VERSIONS = [
    "2.3",
    "2.4",
    "2.5",
    "2.6",
    "2.7",
    "3.0"
]

def fetch_minor_versions(major_version):
  all_minor_versions = []
  resp = requests.get(f'https://cache.ruby-lang.org/pub/ruby/{major_version}/')
  lines = resp.text.split("\n")
  for line in lines:
    if 'tar.gz' in line:
      regex = ">(?P<minor_version>ruby-\d\.\d\.\d.*)\.tar\.gz<"
      version = re.findall(regex, line)[0].split("ruby-")[1]
      all_minor_versions.append(version)
  return all_minor_versions


def image_scraper_handler(event, context):
  sqs_client = boto3.client("sqs", region_name="us-east-1")

  for major_version in MAJOR_VERSIONS:
    all_versions = fetch_minor_versions(major_version)
    for minor_version in all_versions:
      message = { "major_version": major_version, "minor_version": minor_version }
      sqs_client.send_message(
          QueueUrl=env.rubian_build_queue,
          MessageBody=json.dumps(message)
      )
