terraform {
  backend "s3" {
    bucket  = "llb-tfstate"
    key     = "global/s3/terraform.tfstate"
    region  = "eu-west-2"
    encrypt = true
  }
}

resource "aws_instance" "builder" {
  ami                         = "ami-0e991d0f8dca21e20"
  instance_type               = "t4g.micro"
  associate_public_ip_address = true
  key_name                    = "builder-key-pair"
  vpc_security_group_ids      = [data.aws_security_group.ssh-only.id]
  root_block_device {
    volume_size = 12
  }
  tags = {
    Name = "builder"
  }
}

data "aws_security_group" "ssh-only" {
  name = "ssh-only"
}

resource "aws_key_pair" "ssh-key" {
  key_name   = "builder-key-pair"
  public_key = var.ssh_key
}

output "ip" {
  description = "The public ip for ssh access"
  value       = aws_instance.builder.public_ip
}
