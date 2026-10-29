# YC_TOKEN, YC_CLOUD_ID и YC_FOLDER_ID читаются из окружения.
provider "yandex" {
  zone = var.zone
}

data "yandex_compute_image" "ubuntu" {
  family    = var.image_family
  folder_id = var.image_folder_id
}

resource "yandex_vpc_network" "lab" {
  name = var.network_name
}

# Исходящий интернет для установки пакетов на worker без публичного IP.
resource "yandex_vpc_gateway" "nat" {
  name = var.gateway_name
  shared_egress_gateway {}
}

resource "yandex_vpc_route_table" "lab" {
  name       = var.route_table_name
  network_id = yandex_vpc_network.lab.id

  static_route {
    destination_prefix = "0.0.0.0/0"
    gateway_id         = yandex_vpc_gateway.nat.id
  }
}

resource "yandex_vpc_subnet" "lab" {
  name           = var.subnet_name
  zone           = var.zone
  network_id     = yandex_vpc_network.lab.id
  v4_cidr_blocks = [var.subnet_cidr]
  route_table_id = yandex_vpc_route_table.lab.id
}

resource "yandex_vpc_security_group" "web" {
  name       = var.web_sg_name
  network_id = yandex_vpc_network.lab.id

  ingress {
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    port           = 8080
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_vpc_security_group" "worker" {
  name       = var.worker_sg_name
  network_id = yandex_vpc_network.lab.id

  ingress {
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = [var.subnet_cidr]
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

locals {
  cloud_init_common = {
    users = [{
      name                = var.ssh_user
      groups              = ["sudo"]
      shell               = "/bin/bash"
      sudo                = ["ALL=(ALL) NOPASSWD:ALL"]
      lock_passwd         = true
      ssh_authorized_keys = [trimspace(file(pathexpand(var.ssh_public_key_path)))]
    }]
    ssh_pwauth     = false
    package_update = true
  }
}

resource "yandex_compute_instance" "web" {
  name        = var.web_name
  zone        = var.zone
  platform_id = var.platform_id

  resources {
    cores         = var.cores
    memory        = var.memory
    core_fraction = var.core_fraction
  }

  boot_disk {
    auto_delete = true
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = var.disk_size
      type     = var.disk_type
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.lab.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.web.id]
  }

  metadata = {
    user-data = "#cloud-config\n${yamlencode(merge(local.cloud_init_common, {
      packages = ["docker.io"]
      runcmd = [
        ["systemctl", "enable", "--now", "docker"],
        ["docker", "run", "-d", "--restart=always", "--name", "web", "-p", "8080:80", var.web_container_image]
      ]
    }))}"
  }
}

resource "yandex_compute_instance" "worker" {
  name        = var.worker_name
  zone        = var.zone
  platform_id = var.platform_id

  resources {
    cores         = var.cores
    memory        = var.memory
    core_fraction = var.core_fraction
  }

  boot_disk {
    auto_delete = true
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = var.disk_size
      type     = var.disk_type
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.lab.id
    nat                = false
    security_group_ids = [yandex_vpc_security_group.worker.id]
  }

  metadata = {
    user-data = "#cloud-config\n${yamlencode(merge(local.cloud_init_common, {
      packages = ["python3"]
      write_files = [
        {
          path        = "/usr/local/bin/lab-worker.py"
          permissions = "0644"
          content     = <<-PYTHON
            import time
            from datetime import datetime, timezone

            while True:
                with open("/var/log/worker.log", "a", encoding="utf-8") as log:
                    log.write(f"Task {datetime.now(timezone.utc).isoformat()}\n")
                time.sleep(60)
          PYTHON
        },
        {
          path        = "/etc/systemd/system/lab-worker.service"
          permissions = "0644"
          content     = <<-UNIT
            [Unit]
            Description=Lab background worker
            After=network.target

            [Service]
            ExecStart=/usr/bin/python3 /usr/local/bin/lab-worker.py
            Restart=always
            RestartSec=5

            [Install]
            WantedBy=multi-user.target
          UNIT
        }
      ]
      runcmd = [
        ["systemctl", "daemon-reload"],
        ["systemctl", "enable", "--now", "lab-worker.service"]
      ]
    }))}"
  }
}
