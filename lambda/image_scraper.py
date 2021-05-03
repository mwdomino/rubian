import boto3
import env_vars as env
import re
import requests

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

def add_build_to_queue(major_version, minor_version):
  env = env.Environment()
  sqs_client = boto3.client("sqs", region_name="us-east-1")
  message = { "major_version": major_version, "minor_version": minor_version }

  sqs_client.send_message(
    QueueUrl=env.rubian_build_queue,
    MessageBody=json.dumps(message)
  )
