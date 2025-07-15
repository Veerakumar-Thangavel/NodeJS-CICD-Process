# 1. Create VPC
resource "aws_vpc" "node_js_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = var.project_tag
  }
}

# 2. Create Public Subnet
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.node_js_vpc.id
  cidr_block              = var.public_subnet_cidr
  map_public_ip_on_launch = true
  availability_zone       = "${var.region}a"

  tags = {
    Name = "${var.project_tag}-public"
  }
}

# 3. Create Private Subnet
resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.node_js_vpc.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = "${var.region}b"

  tags = {
    Name = "${var.project_tag}-private"
  }
}

# 4. Create Public Route Table
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.node_js_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_internet_gateway.id
  }

  tags = {
    Name = "${var.project_tag}-public"
  }
}

# 5. Create Private Route Table
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.node_js_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = {
    Name = "${var.project_tag}-private"
  }
}

# 6. Associate Public Route Table with Public Subnet
resource "aws_route_table_association" "public_route_table_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

# 7. Associate Private Route Table with Private Subnet
resource "aws_route_table_association" "private_route_table_association" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_route_table.id
}

# 8. NAT Gateway
resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id
  depends_on    = [aws_internet_gateway.my_internet_gateway]
}

# 9. Create Internet Gateway
resource "aws_internet_gateway" "my_internet_gateway" {
  vpc_id = aws_vpc.node_js_vpc.id

  tags = {
    Name = var.project_tag
  }
}

# 10. Bastion Host in Public Subnet
resource "aws_instance" "bastion_host" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public_subnet.id
  vpc_security_group_ids      = [aws_security_group.allow_ssh.id, aws_security_group.allow_jenkins.id]
  key_name                    = aws_key_pair.nodejs_key.key_name
  associate_public_ip_address = true
  user_data                   = file("${path.module}/shell.sh")


  tags = {
    Name = "${var.project_tag}-bastion"
  }

  depends_on = [aws_internet_gateway.my_internet_gateway]

  provisioner "local-exec" {
    command = "echo ${self.private_ip}"
  }
}

# 11. Private Application Host
resource "aws_instance" "application" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private_subnet.id
  vpc_security_group_ids = [aws_security_group.allow_ssh_and_port_3000.id]
  key_name               = aws_key_pair.nodejs_key.key_name

  tags = {
    Name = "${var.project_tag}-app"
  }
}

# 12. key pair
resource "aws_key_pair" "nodejs_key" {
  key_name   = "nodejs-key"
  public_key = file("${path.module}/id_rsa.pub")
}

# 13. Security Group 
resource "aws_security_group" "allow_ssh" {
  name        = "allow-ssh"
  description = "Allow SSH"
  vpc_id      = aws_vpc.node_js_vpc.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow-ssh"
  }
}

# 14. SG 3000
resource "aws_security_group" "allow_ssh_and_port_3000" {
  name        = "allow-ssh-3000"
  description = "Allow SSH and Port 3000"
  vpc_id      = aws_vpc.node_js_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow-ssh-and-3000"
  }
}

# 15. SG for the Jenkins 
resource "aws_security_group" "allow_jenkins" {
  name        = "allow-jenkins"
  description = "Allow Jenkins Web UI"
  vpc_id      = aws_vpc.node_js_vpc.id

  ingress {
    description = "Allow Jenkins UI"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow-jenkins"
  }
}
