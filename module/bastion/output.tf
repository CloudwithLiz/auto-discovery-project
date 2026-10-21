data "aws_instances" "bastion" {
  filter {
    name   = "tag:Name"
    values = ["${var.name}-bastion"]
  }

  instance_state_names = ["running"]

  depends_on = [aws_autoscaling_group.bastion_asg]
}

output "bastion_public_ip" {
  value       = data.aws_instances.bastion.public_ips
  description = "Public IP address(es) of the current Bastion Host instance(s)"
}

output "bastion_instance_id" {
  value       = data.aws_instances.bastion.ids
  description = "The EC2 Instance ID(s) of the current Bastion Host instance(s)"
}

output "bastion_asg_name" {
  value       = aws_autoscaling_group.bastion_asg.name
  description = "Name of the Bastion Host Auto Scaling Group"
}

output "bastion_sg_id" {
  value       = aws_security_group.bastion_sg.id
  description = "Security group ID of the Bastion Host"
}