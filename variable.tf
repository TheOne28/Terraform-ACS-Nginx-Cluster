variable "aws_access_key" {
  type = string
}

variable "aws_secret_key" {
  type = string
}
variable "availability_zones" {
  type    = list(any)
  default = ["ap-southeast-1a", "ap-southeast-1b"]
}

variable "cidr_block" {
  type    = string
  default = "10.32.0.0/16"
}

variable "public_cidr_block" {
  type    = list(any)
  default = ["10.32.0.0/26", "10.32.1.0/26"]
}

variable "private_cidr_block" {
  type    = list(any)
  default = ["10.32.2.0/26", "10.32.3.0/26"]
}

variable "app_count" {
  type    = number
  default = 1
}
