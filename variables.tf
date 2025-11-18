variable "component_name" {    # comes from root module
    type = string
    default = "catalogue"

}

variable "ami_id" {
    type = string

}

variable "project_name" {
    type = string
    default = "roboshop"
}

variable "environment" {
    type = string
    default = "dev"
}

variable "zone_id" {
    default = "Z04092822ZCUHU7SWZ18H"
}

variable "domain_name" {
    default = "vigi-devops.fun"
}

variable "rule_priority" {
    type = number
}