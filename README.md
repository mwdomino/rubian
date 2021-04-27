#### Rubian
This repository consists of a base image `mwdomino/rubian-base` which is a 
fresh pull of the most recent debian image on DockerHub with necessary build 
dependencies added. Next, ruby is built from source inside the container. This
process will automatically build and push new versions as the debian:latest
container receives updates.

#### Technical Details
![diagram](https://github.com/mwdomino/rubian/blob/master/images/diagram.png?raw=true)

The entire build process happens on AWS with an attempt to be as serverless as
possible. All files required to replicate the deployment are available in the `aws/`
subfolder.

1. Lambda function runs every hour via CloudWatch events and pulls sha256 of current
`debian:latest` image, storing the result in S3.
2. Event fires on any update to the `version` file in S3 if hash has changed
3. Lambda function scrapes ruby-lang.org for all available ruby releases and adds
the required metadata to SQS queue
4. Autoscaling Group of EC2 instances scales up from 0 -> 10 when messages arrive in
SQS.
5. EC2 instances peel jobs off the queue and build, tag, and push the updated container
images to DockerHub.
6. Alarm fires if EC2 instance is alive for more than 55min, killing them to ensure no
billing surprises.

Each build takes roughly 5 minutes with a total of 65 current rubies in scope for this
project. I'll be adjusting the size of the ASG and instance specifics if I find a more
efficient combination.

#### TODO
* scan images with static vulnerability scanners and store output in S3 with public
access
* store build output in S3
* CloudWatch logs instead of `print()` statements
* Jenkins to trigger above process on merge
* build ARM images?
* move python deps to /vendor folder
