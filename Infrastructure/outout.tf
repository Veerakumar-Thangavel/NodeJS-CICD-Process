# Outputs
#output "vpc_id" {
  #description = "ID of the VPC"
  #value       = module.network.vpc_id
# }

output "bastion_public_ip" {
  description = "Public IP of the bastion host"
  value       = aws_instance.bastion_host.public_ip
}

output "application_private_ip" {
  description = "Private IP of the application server"
  value       = aws_instance.application.private_ip
}

output "ssm_parameter_name" {
  description = "SSM parameter storing private key"
  value       = aws_ssm_parameter.private_key.name
}

output "ssh_key_instructions" {
  value = "aws ssm get-parameter --name ${aws_ssm_parameter.private_key.name} --with-decryption --query Parameter.Value --output text > private_key.pem && chmod 400 private_key.pem"
}

resource "aws_ssm_parameter" "private_key" {
  name  = "/ec2/keypair/private"
  type  = "SecureString"
  value = file("${path.module}/id_rsa") # Make sure id_rsa is present
}


#output "vpc_id" {
 # value = aws_vpc.node_js_vpc.id
#}

output "public_subnet_id" {
  value = aws_subnet.public_subnet.id
}

output "private_subnet_id" {
  value = aws_subnet.private_subnet.id
}

