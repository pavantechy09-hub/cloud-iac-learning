resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "bank-db-vpc" }
}

resource "aws_subnet" "data_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1a"
  tags = { Name = "data-subnet-a", Tier = "data" }
}

resource "aws_security_group" "db" {
  name        = "db-sg"
  description = "Allow Postgres only from app tier"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Postgres from app subnet only"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.2.0/24"]
  }
}

resource "aws_db_instance" "accounts_db" {
  identifier             = "accounts-db"
  engine                 = "postgres"
  engine_version         = "15.4"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  db_name                = "accounts"
  username               = "bankadmin"
  password               = "TempPassword123!"
  vpc_security_group_ids = [aws_security_group.db.id]
  backup_retention_period    = 7
  deletion_protection        = false
  skip_final_snapshot        = true
  storage_encrypted          = true
  auto_minor_version_upgrade = true
}
resource "aws_secretsmanager_secret" "db_password" {
  name                    = "bank/accounts-db/password"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "db_password" {
  secret_id     = aws_secretsmanager_secret.db_password.id
  secret_string = jsonencode({
    username = "bankadmin"
    password = "TempPassword123!"
    host     = aws_db_instance.accounts_db.address
    port     = aws_db_instance.accounts_db.port
    dbname   = aws_db_instance.accounts_db.db_name
  })
}

resource "aws_s3_bucket" "transaction_archive" {
  bucket = "bank-transaction-archive"
}

resource "aws_s3_bucket_versioning" "transaction_archive" {
  bucket = aws_s3_bucket.transaction_archive.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "transaction_archive" {
  bucket = aws_s3_bucket.transaction_archive.id

  rule {
    id     = "archive-old-transactions"
    status = "Enabled"

    filter {}

    transition {
      days          = 90
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 365
      storage_class = "GLACIER"
    }

    expiration {
      days = 2555
    }
  }
}

resource "aws_s3_bucket_public_access_block" "transaction_archive" {
  bucket = aws_s3_bucket.transaction_archive.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "flow_logs" {
  bucket = aws_s3_bucket.flow_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
