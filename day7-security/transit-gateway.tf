resource "aws_vpc" "prod" {
  cidr_block = "10.0.0.0/16"
  tags = { Name = "prod-vpc" }
}

resource "aws_vpc" "dev" {
  cidr_block = "10.1.0.0/16"
  tags = { Name = "dev-vpc" }
}

resource "aws_vpc" "security" {
  cidr_block = "10.2.0.0/16"
  tags = { Name = "security-vpc" }
}

resource "aws_subnet" "prod_subnet" {
  vpc_id     = aws_vpc.prod.id
  cidr_block = "10.0.1.0/24"
  tags = { Name = "prod-subnet" }
}

resource "aws_subnet" "dev_subnet" {
  vpc_id     = aws_vpc.dev.id
  cidr_block = "10.1.1.0/24"
  tags = { Name = "dev-subnet" }
}

resource "aws_subnet" "security_subnet" {
  vpc_id     = aws_vpc.security.id
  cidr_block = "10.2.1.0/24"
  tags = { Name = "security-subnet" }
}

# Transit Gateway - not supported in Floci
# Works on real AWS - code below is production-ready
#
# resource "aws_ec2_transit_gateway" "main" {
#   description                     = "Bank central transit gateway"
#   amazon_side_asn                 = 64512
#   auto_accept_shared_attachments  = "enable"
#   default_route_table_association = "enable"
#   default_route_table_propagation = "enable"
#   tags = { Name = "bank-tgw" }
# }
#
# resource "aws_ec2_transit_gateway_vpc_attachment" "prod" {
#   transit_gateway_id = aws_ec2_transit_gateway.main.id
#   vpc_id             = aws_vpc.prod.id
#   subnet_ids         = [aws_subnet.prod_subnet.id]
#   tags = { Name = "prod-attachment" }
# }
#
# resource "aws_ec2_transit_gateway_vpc_attachment" "dev" {
#   transit_gateway_id = aws_ec2_transit_gateway.main.id
#   vpc_id             = aws_vpc.dev.id
#   subnet_ids         = [aws_subnet.dev_subnet.id]
#   tags = { Name = "dev-attachment" }
# }
#
# resource "aws_ec2_transit_gateway_vpc_attachment" "security" {
#   transit_gateway_id = aws_ec2_transit_gateway.main.id
#   vpc_id             = aws_vpc.security.id
#   subnet_ids         = [aws_subnet.security_subnet.id]
#   tags = { Name = "security-attachment" }
# }