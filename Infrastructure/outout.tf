output "vpc_id" {
  value = aws_vpc.node_js_vpc.id
}

output "public_subnet_id" {
  value = aws_subnet.public_subnet.id
}

output "private_subnet_id" {
  value = aws_subnet.private_subnet.id
}

output "bastion_host_id" {
  value = aws_instance.bastion_host.id
}

output "application_host_id" {
  value = aws_instance.application.id
}

output "bastion_public_ip" {
  value = aws_eip.bastion_eip.public_ip
}

output "application_private_ip" {
  value = aws_instance.application.private_ip
}
