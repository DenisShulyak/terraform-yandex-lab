variable "network_name" {
  type    = string
  default = "tf-lesson-vpc"
}

variable "subnet_name" {
  type    = string
  default = "tf-lesson-subnet"
}

variable "subnet_cidr" {
  type    = string
  default = "10.10.0.0/24"
}

variable "zone" {
  type    = string
  default = "ru-central1-a"
}

variable "platform_id" {
  description = "Тип платформы CPU в Yandex Compute Cloud."
  type        = string
  default     = "standard-v3"
}

variable "cores" {
  type    = number
  default = 2
}

variable "memory" {
  description = "Объём RAM в ГБ."
  type        = number
  default     = 2
}

variable "core_fraction" {
  type    = number
  default = 20
}

variable "disk_size" {
  description = "Размер загрузочного диска в ГБ."
  type        = number
  default     = 10
}

variable "disk_type" {
  type    = string
  default = "network-hdd"
}

variable "image_family" {
  type    = string
  default = "ubuntu-2204-lts"
}

variable "image_folder_id" {
  description = "Публичный каталог образов Yandex Cloud."
  type        = string
  default     = "standard-images"
}

variable "web_name" {
  type    = string
  default = "web"
}

variable "worker_name" {
  type    = string
  default = "worker"
}

variable "web_sg_name" {
  type    = string
  default = "tf-lesson-web-sg"
}

variable "worker_sg_name" {
  type    = string
  default = "tf-lesson-worker-sg"
}

variable "gateway_name" {
  type    = string
  default = "tf-lesson-nat"
}

variable "route_table_name" {
  type    = string
  default = "tf-lesson-routes"
}

variable "ssh_user" {
  type    = string
  default = "ubuntu"
}

variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/terraform_lab.pub"
}

variable "web_container_image" {
  type    = string
  default = "nginx:stable-alpine"
}
