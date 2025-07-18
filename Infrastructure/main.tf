# -------------------- 0. Key Pair (PEM) --------------------
resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "nodejs_key" {
  key_name   = "nodejs-key"
  public_key = tls_private_key.ec2_key.public_key_openssh
}

resource "local_file" "ec2_key_pem" {
  filename = "${path.module}/nodejs-key.pem"
  content         = tls_private_key.ec2_key.private_key_pem
  file_permission = "0400"
}

# -------------------- 1. VPC --------------------
resource "aws_vpc" "node_js_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = var.project_tag
  }
}

# -------------------- 2. Public Subnet --------------------
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.node_js_vpc.id
  cidr_block              = var.public_subnet_cidr
  map_public_ip_on_launch = true
  availability_zone       = "${var.region}a"

  tags = {
    Name = "${var.project_tag}-public"
  }
}

# -------------------- 3. Private Subnet --------------------
resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.node_js_vpc.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = "${var.region}b"

  tags = {
    Name = "${var.project_tag}-private"
  }
}

# -------------------- 4. Internet Gateway --------------------
resource "aws_internet_gateway" "my_internet_gateway" {
  vpc_id = aws_vpc.node_js_vpc.id

  tags = {
    Name = var.project_tag
  }
}

# -------------------- 5. Route Tables --------------------
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

resource "aws_route_table_association" "public_route_table_association" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id
  depends_on    = [aws_internet_gateway.my_internet_gateway]
}

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

resource "aws_route_table_association" "private_route_table_association" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_route_table.id
}

# -------------------- 6. Security Groups --------------------
resource "aws_security_group" "allow_ssh" {
  name        = "allow-ssh"
  vpc_id      = aws_vpc.node_js_vpc.id
  description = "Allow SSH from anywhere"

  ingress {
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
}

resource "aws_security_group" "allow_ssh_and_port_3000" {
  name        = "allow-ssh-3000"
  description = "Allow SSH and App Port 3000"
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
}

resource "aws_security_group" "allow_jenkins" {
  name        = "allow-jenkins"
  description = "Allow Jenkins UI"
  vpc_id      = aws_vpc.node_js_vpc.id

  ingress {
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
}

# -------------------- 7. Bastion Host --------------------
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
}

# -------------------- 8. Application Host --------------------
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
