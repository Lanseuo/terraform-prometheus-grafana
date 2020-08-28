data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "instance" {
  ami                  = data.aws_ami.ubuntu.id
  instance_type        = "t2.nano"
  user_data            = data.template_file.cloud_config_script.rendered
  security_groups      = [aws_security_group.security_group.name]
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  tags = {
    Name = "Monitoring"
  }
}

data "template_file" "cloud_config_script" {
  template = file("${path.module}/cloud.conf")

  vars = {
    prometheus_version    = "2.20.1"
    alertmanager_version  = "0.21.1"
    prometheus_hostname   = var.prometheus_hostname
    alertmanager_hostname = var.alertmanager_hostname
    config_bucket_name    = var.config_bucket_name
  }
}

resource "aws_security_group" "security_group" {
  name        = "monitoring"
  description = "Security group for monitoring instance"

  ingress {
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "Monitoring"
  }
}

resource "aws_s3_bucket" "config_bucket" {
  bucket = var.config_bucket_name

  tags = {
    Name = "Monitoring Config"
  }
}

resource "aws_iam_role" "ec2_role" {
  name               = "MonitoringEC2Instance"
  description        = "Allows EC2 instances to call AWS services on your behalf."
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2_profile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_iam_role_policy_attachment" "test-attach" {
  role       = aws_iam_role.ec2_role.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}