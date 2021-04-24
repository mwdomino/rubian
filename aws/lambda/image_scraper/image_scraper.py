import boto3
import json
import os
import re
import requests

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


def handler(event, context):
  queue_url = os.environ.get('RUBIAN_BUILD_QUEUE')
  sqs_client = boto3.client("sqs", region_name="us-east-1")

  for major_version in MAJOR_VERSIONS:
    all_versions = fetch_minor_versions(major_version)
    for minor_version in all_versions:
      major_version = minor_version.rsplit('.', 1)[0]
      message = { "major_version": major_version, "minor_version": minor_version }
      sqs_client.send_message(
          QueueUrl=queue_url,
          MessageBody=json.dumps(message)
      )
