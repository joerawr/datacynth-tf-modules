terraform {
  required_version = ">= 1.12.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  profile = var.aws_profile
  region  = var.aws_region
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  # Get the list of all available AZs and select a subset of them
  # based on the az_count variable. 
  # Slice from index 0 will pick the first avaiable az, and so on
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)
}

resource "aws_vpc" "main" {
  cidr_block                       = var.vpc_cidr
  enable_dns_hostnames             = true
  enable_dns_support               = true
  assign_generated_ipv6_cidr_block = var.ipv6_enabled
  tags = {
    Name = var.name
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_subnet" "public" {
  count                   = var.public_subnet_count
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  availability_zone       = local.azs[count.index % var.az_count]
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.name}-public"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
}

resource "aws_route_table_association" "public" {
  count          = var.public_subnet_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# EC2 assume-role trust policy
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    sid     = "EC2AssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# Role for the NAT instance to talk to SSM
resource "aws_iam_role" "nat_ssm_role" {
  name               = "${var.name}-nat-ssm-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

# Attach the minimum managed policy for Session Manager, inventory, etc.
resource "aws_iam_role_policy_attachment" "nat_ssm_core" {
  role       = aws_iam_role.nat_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance profile to attach to the EC2 instance
resource "aws_iam_instance_profile" "nat_ssm_profile" {
  name = "${var.name}-nat-ssm-profile"
  role = aws_iam_role.nat_ssm_role.name
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = [var.nat_instance_ami_filter]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "nat" {
  name        = "${var.name}-nat-instance-sg"
  description = "Allow egress traffic from private subnets"
  vpc_id      = aws_vpc.main.id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "nat" {
  count                  = var.nat_instance_enabled ? 1 : 0
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.nat_instance_type
  subnet_id              = aws_subnet.public[0].id
  source_dest_check      = false
  vpc_security_group_ids = [aws_security_group.nat.id]
  iam_instance_profile   = aws_iam_instance_profile.nat_ssm_profile.name
  user_data_replace_on_change = true
  depends_on             = [aws_internet_gateway.main]
  user_data              = <<-EOF
              #!/bin/bash
              # Redirect all output to a log file for troubleshooting
              exec > >(tee /var/log/user_data.log|logger -t user-data -s 2>/dev/console) 2>&1

              set -eu

              echo "Enabling IP forwarding..."
              echo 1 > /proc/sys/net/ipv4/ip_forward

              echo "Installing iptables and configuring NAT..."
              # Amazon Linux 2023 doesn't include iptables by default.
              dnf install -y iptables-services
              systemctl enable --now iptables

              # Find the default network interface
              IFACE=$(ip -o -4 route show to default | awk '{print $5}')
              echo "Default interface is $${IFACE}"

              # Flush the FORWARD chain for a clean slate
              iptables -F FORWARD

              # Add the masquerading rule
              iptables -t nat -A POSTROUTING -o "${IFACE}" -j MASQUERADE

              # Save the rules to persist across reboots
              service iptables save
              echo "iptables NAT configuration complete."

              echo "Ensuring SSM agent is installed and running..."
              # Ensure SSM agent is installed & running (Amazon Linux 2023)
              if ! systemctl list-unit-files | grep -q amazon-ssm-agent; then
                echo "SSM agent not found, attempting installation..."
                dnf install -y amazon-ssm-agent || yum install -y amazon-ssm-agent || true
              fi
              systemctl enable --now amazon-ssm-agent || true
              echo "SSM agent setup complete."
              EOF
  tags = {
    Name = "${var.name}-nat-instance"
  }
}

resource "aws_eip" "nat" {
  count    = var.nat_instance_enabled ? 1 : 0
  instance = aws_instance.nat[0].id
  domain   = "vpc"
}

resource "aws_subnet" "private" {
  count             = var.private_subnet_count
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(aws_vpc.main.cidr_block, 8, var.public_subnet_count + count.index)
  availability_zone = local.azs[count.index % var.az_count]
  tags = {
    Name = "${var.name}-private"
  }
}

resource "aws_route_table" "private" {
  count  = var.private_subnet_count
  vpc_id = aws_vpc.main.id
}

resource "aws_route" "private_nat" {
  count                  = var.nat_instance_enabled ? var.private_subnet_count : 0
  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.nat[0].primary_network_interface_id
}

resource "aws_route_table_association" "private" {
  count          = var.private_subnet_count
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_vpc_endpoint" "s3" {
  count           = var.s3_gateway_enabled ? 1 : 0
  vpc_id          = aws_vpc.main.id
  service_name    = "com.amazonaws.${var.aws_region}.s3"
  route_table_ids = [for rt in aws_route_table.private : rt.id]
}

# Security group for VPC endpoints (allow HTTPS from inside the VPC)
resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.name}-vpce-sg"
  description = "Allow HTTPS from VPC to interface endpoints"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.main.cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Choose which subnets host the endpoints (typically private subnets)
locals {
  vpce_subnet_ids = length(aws_subnet.private) > 0 ? [for s in aws_subnet.private : s.id] : [for s in aws_subnet.public : s.id]
}

resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.vpce_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.vpce_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = local.vpce_subnet_ids
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
}

resource "aws_security_group" "private" {
  name        = "${var.name}-private-sg"
  description = "Allow inbound traffic for private instances"
  vpc_id      = aws_vpc.main.id

  dynamic "ingress" {
    for_each = toset(var.private_ingress_ports)
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = [aws_vpc.main.cidr_block]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
