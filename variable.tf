variable "CIDR" {
  default = "10.0.0.0/26"

}

variable "sub1-CIDR" {
  description = "subet1 var"
  default     = "10.0.0.0/28"

}

variable "sub2-CIDR" {
  default = "10.0.0.16/28"
}