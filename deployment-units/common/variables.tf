variable "aws_region" {
  type        = string
  description = "AWS region"
  default     = "eu-west-2" // London
}

variable "aws_access_key" {
  type        = string
  description = "AWS access key"
}

variable "aws_secret_key" {
  type        = string
  description = "AWS secret key"
}

variable "ssh_key" {
  type        = string
  description = "An authorized SSH key to ssh in the EC2 instance"
}
