import boto3
import env_vars as env
import requests

def get_digest():
  env = env.Environment()
  headers = { "Accept": "application/vnd.docker.distribution.manifest.list.v2+json" }
  auth = auth(env.docker_hub_username, env.docker_hub_password)

  token = requests.get(
    'https://auth.docker.io/token?scope=repository:library/debian:pull&service=registry.docker.io',
    auth=auth, headers=headers).json()['token']

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
