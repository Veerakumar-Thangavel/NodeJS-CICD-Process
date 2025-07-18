terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.0.2"
      
    }
  }
  
}

# Configure the AWS Provider
provider "aws" {
  region  = "us-east-1"
 # profile = "default"
}

#provider "docker" {
    #version = "~> 3.0.2"
  #  host = "unix:///var/run/docker.sock"

 # registry_auth {
    #address  = "registry-1.docker.io"
   #  password = var.dockerhub_password
 # }
#}

# Kubernetes provider configuration using data source
#provider "kubernetes" {
 # host                   = data.aws_eks_cluster.my_cluster_data.endpoint
  #cluster_ca_certificate = base64decode(data.aws_eks_cluster.my_cluster_data.certificate_authority[0].data)
  #token                  = data.aws_eks_cluster_auth.my_cluster_auth.token
#}

# Helm provider configuration using data source
#provider "helm" {
  #kubernetes {
   # host                   = data.aws_eks_cluster.my_cluster_data.endpoint
    #cluster_ca_certificate = base64decode(data.aws_eks_cluster.my_cluster_data.certificate_authority[0].data)
    #token                  = data.aws_eks_cluster_auth.my_cluster_auth.token
  #}
#}
