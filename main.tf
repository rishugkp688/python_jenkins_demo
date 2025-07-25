# main.tf

# --- Provider Configuration ---
# Specifies the AWS provider and the region where the resources will be created.
# IMPORTANT: Hardcoding credentials is not recommended for production environments.
# Use IAM roles, environment variables, or shared credentials files instead.
provider "aws" {
  # Changed default region to ap-south-1 (Mumbai). You can change this to your preferred region.
  region     = "ap-south-1"
  access_key = "AWS_ACCESS_KEY"
  secret_key = "AWS_SECRET_KEY"
}

# --- Data Source: Find the latest Ubuntu AMI ---
# This data source automatically finds the most recent Ubuntu 22.04 LTS AMI
# in the specified region. This is more reliable than hardcoding an AMI ID.
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical's AWS account ID
}


# --- Resource: AWS Security Group ---
# This security group allows all inbound and outbound traffic.
# This is insecure and should only be used for temporary testing purposes.
resource "aws_security_group" "allow_all" {
  name        = "allow_all_traffic"
  description = "Allow all inbound and outbound traffic, including SSH and Jenkins"

  # Ingress rule to allow all incoming traffic from any source.
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # '-1' signifies all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Egress rule to allow all outgoing traffic to any destination.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_all_sg"
  }
}

# --- Resource: AWS EC2 Instance ---
# This defines the EC2 instance that will be created.
resource "aws_instance" "web_server" {
  # Use the ID from the data source to get the correct AMI for the region.
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.micro" # Free-tier eligible instance type

  # Associates the 'allow_all' security group with this instance.
  vpc_security_group_ids = [aws_security_group.allow_all.id]

  # The name of the key pair to use for SSH access.
  # Make sure you have this key pair in your AWS account and the private key locally.
  key_name = "laura" # <-- IMPORTANT: Replace with your key pair name

  # Tags are key-value pairs that help you manage, identify, organize, search for, and filter resources.
  tags = {
    Name = "Jenkins-Docker-Server-Ubuntu"
  }

  # --- User Data ---
  # This script runs automatically when the instance first boots up.
  # It's a more reliable method than the remote-exec provisioner for initial setup.
  # The script is run as the root user.
  user_data = <<-EOF
              #!/bin/bash
              set -e # Exit immediately if a command exits with a non-zero status.

              # Update package lists
              apt-get update -y

              # Create and enable a 2GB swap file to provide more memory for Jenkins on a t2.micro
              if ! grep -q "/swapfile" /etc/fstab; then
                fallocate -l 2G /swapfile
                chmod 600 /swapfile
                mkswap /swapfile
                swapon /swapfile
                echo '/swapfile none swap sw 0 0' >> /etc/fstab
              fi

              # Install Java 17, a modern LTS version compatible with recent Jenkins
              sudo apt install fontconfig openjdk-21-jre -y
              
              # Install Docker
              apt-get install -y docker.io
              systemctl start docker
              systemctl enable docker
              usermod -aG docker ubuntu
              
              # Install Jenkins
              curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | tee /usr/share/keyrings/jenkins-keyring.asc > /dev/null
              echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/ | tee /etc/apt/sources.list.d/jenkins.list > /dev/null
              apt-get update
              apt-get install -y jenkins
              sudo usermod -aG docker jenkins

              # Start Jenkins
              systemctl start jenkins
              EOF

  # This tells Terraform to ignore changes to user_data after the instance is created.
  lifecycle {
    ignore_changes = [user_data]
  }
}

# --- Outputs ---
# These outputs will display the public IP address and DNS of the created instance
# after you run 'terraform apply'.
output "instance_public_ip" {
  value       = aws_instance.web_server.public_ip
  description = "Public IP address of the EC2 instance."
}

output "instructions" {
  value = "Instance is being created. The setup script (user_data) is running in the background and may take 5-10 minutes to complete. Access Jenkins at http://${aws_instance.web_server.public_dns}:8080. To get the admin password, SSH into the instance (using user 'ubuntu') and run: sudo cat /var/lib/jenkins/secrets/initialAdminPassword"
}
