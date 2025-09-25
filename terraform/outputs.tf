output "public_ip" {
  value = { for k, v in aws_instance.app : k => v.public_ip }
}

output "vpc_id" {
  value = { for k, v in aws_vpc.this : k => v.id }
}

