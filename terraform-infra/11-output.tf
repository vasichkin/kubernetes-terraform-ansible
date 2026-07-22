output "k8s_master_public_ip" {
  value = aws_instance.k8s_master.public_ip
}
output "k8s_worker_private_ip" {
  value = aws_instance.k8s_worker[*].private_ip
}
output "alb_dns_name" {
  value = aws_lb.this.dns_name
}