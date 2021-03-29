terraform {
  backend "s3" {
    bucket  = "llb-tfstate"
    key     = "global/s3/terraform.tfstate"
    region  = "eu-west-2"
    encrypt = true
  }
}

resource "aws_instance" "example" {
  ami                         = "ami-01c835443b86fe988"
  instance_type               = "t2.micro"
  associate_public_ip_address = true
  key_name                    = "example-key-pair"
  vpc_security_group_ids      = [data.aws_security_group.ssh-only.id]
  tags = {
    Name = "Example"
  }
}

data "aws_security_group" "ssh-only" {
  name = "ssh-only"
}

resource "aws_key_pair" "ssh-key" {
  key_name   = "example-key-pair"
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDil2voRN74OWtXMdkDr3trbz34L3qbJSVqbgZmrwpWU5Bhcrbe4A9LcKKcbPCJnVafWBuatQG6VTkxqpER3VXxTk9OhopUKjeVWijorS/RAJQEjEzAulQvi1dXKnD3ty9Z78NweFrBlDgYWjH5QZPCxM3D9+8K8/L83pOMrZXBpmzwptrYLZVjXKDO17Ha+oZ2Wnmm2OtqfmO9HE6UXV/amZTjLFR6BvjLMoekDU1poozszZRLQBy1h0BX7bGDbodbROByiGZc/wg7KDg6cTHPmDobOo6ZC2ADK6Mw4ps3nUZPnNdJliVD7uRYORxXDcSifoQF3R3a1d675XF4aLIUZ8gBTg/Xn7N8xHINOEZWTPERGYQiVBR8I3N4RcdzBojQoY67m3O0NPfoM2gPQlHpWyCSZISzfNy9hsRr/unc7vDaMnzFftYKaY1dcw1/958ua4PFxZQKQUp6rAU/Qa5+vZfbhAr3VV2umVFCrJbed4+a2H2aJKJ1whw5c2u9K6KnWpmpEWaThp90OUZiQmq5uJLdysYBgjLgU8+2AGVVFKCe7RJpWA1JGmfUv020b3vqFytBvxi8zj3NrbqRaMhnIKVuFB1hHcL61/ztwe7ImgY6XkTD30aTFVsUYPJ4hFzgbRGCvNZIdnZ13HVZBebk/W2jF6QrKKpdNKTU9O/XWw=="
}

output "instance_ip" {
  description = "The public ip for ssh access"
  value       = aws_instance.example.public_ip
}
