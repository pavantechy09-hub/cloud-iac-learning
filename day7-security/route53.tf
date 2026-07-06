resource "aws_route53_zone" "private" {
  name = "bank.internal"

  tags = {
    Name        = "bank-internal-dns"
    Environment = "prod"
  }
}

resource "aws_route53_record" "accounts_db" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "accounts-db.bank.internal"
  type    = "CNAME"
  ttl     = 300
  records = ["localhost"]
}

resource "aws_route53_record" "accounts_service" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "accounts-service.bank.internal"
  type    = "A"
  ttl     = 60
  records = ["10.0.1.10"]
}

resource "aws_route53_record" "payments_service" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "payments-service.bank.internal"
  type    = "A"
  ttl     = 60
  records = ["10.0.1.11"]
}

resource "aws_route53_record" "fraud_service" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "fraud-service.bank.internal"
  type    = "A"
  ttl     = 60
  records = ["10.0.1.12"]
}

# VPC association - not supported in Floci, works on real AWS
# vpc {
#   vpc_id = aws_vpc.prod.id
# }