resource "aws_route53_zone" "prod" {
  name = var.base_domain_name
}

resource "aws_route53_record" "prod" {
  zone_id = aws_route53_zone.prod.zone_id
  name    = var.base_domain_name
  type    = "A"
  ttl     = "300"
  records = [aws_instance.web.public_ip]
}
