output "web_public_ip" {
  value = yandex_compute_instance.web.network_interface[0].nat_ip_address
}

output "web_private_ip" {
  value = yandex_compute_instance.web.network_interface[0].ip_address
}

output "worker_private_ip" {
  value = yandex_compute_instance.worker.network_interface[0].ip_address
}

output "web_url" {
  value = "http://${yandex_compute_instance.web.network_interface[0].nat_ip_address}:8080"
}
