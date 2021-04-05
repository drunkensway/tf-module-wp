variable "cluster_name" {
  description = "The name to use for all the cluster resources"
  type = string
}

variable "server_port" {
  type        = number
  default     = 8080
  description = "port number used by the web server instance"
}

variable "ssh_port" {
  type = number
  default = 22
  description = "port number used by ssh"
}

variable "instance_type" {
  description = "The type of ec2 instances to run"
  type = string
}

variable "min_size" {
  description = "The minimum number of ec2 instances in the ASG"
  type = number
}

variable "max_size" {
  description = "The maximum number of ec2 instances in the ASG"
  type = number
}