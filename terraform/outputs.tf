output "lb-endpoint" {
  value = aws_lb.ecs-fargate-lb.dns_name
}