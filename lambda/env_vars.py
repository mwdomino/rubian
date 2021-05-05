import os

# Helpers for accessing environment variables
class Environment():
    def __init__(self):
        self.docker_hub_username = self.fetch("DOCKER_HUB_USERNAME")
        self.docker_hub_password = self.fetch("DOCKER_HUB_PASSWORD")
        self.rubian_base_bucket  = self.fetch("RUBIAN_BASE_BUCKET")
        self.rubian_build_queue  = self.fetch("RUBIAN_BUILD_QUEUE")

    def fetch(self, key):
        return os.environ.get(key)
