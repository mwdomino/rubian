variable "docker_hub_username" {
  type = string
  description = "Username to push rubian images through"
}

variable "docker_hub_password" {
  type = string
  description = "Docker Hub password"
}

variable "rubian_dockerfile_url" {
  type = string
  description = "Dockerfile URL to build images from"
}
