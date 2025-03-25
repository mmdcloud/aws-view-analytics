# Frontend Module
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# VPC Configuration
module "vpc" {
  source                = "./modules/vpc/vpc"
  vpc_name              = "view-analytics-vpc"
  vpc_cidr_block        = "10.0.0.0/16"
  enable_dns_hostnames  = true
  enable_dns_support    = true
  internet_gateway_name = "vpc_igw"
}

# Security Group
module "security_group" {
  source = "./modules/vpc/security_groups"
  vpc_id = module.vpc.vpc_id
  name   = "view-analytics-security-group"
  ingress = [
    {
      from_port       = 80
      to_port         = 80
      protocol        = "tcp"
      self            = "false"
      cidr_blocks     = ["0.0.0.0/0"]
      security_groups = []
      description     = "any"
    }
  ]
  egress = [
    {
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

# Public Subnets
module "public_subnets" {
  source = "./modules/vpc/subnets"
  name   = "view-analytics-public-subnet"
  subnets = [
    {
      subnet = "10.0.1.0/24"
      az     = "us-east-1a"
    },
    {
      subnet = "10.0.2.0/24"
      az     = "us-east-1b"
    },
    {
      subnet = "10.0.3.0/24"
      az     = "us-east-1c"
    }
  ]
  vpc_id                  = module.vpc.vpc_id
  map_public_ip_on_launch = true
}

# Private Subnets
module "private_subnets" {
  source = "./modules/vpc/subnets"
  name   = "view-analytics-private-subnet"
  subnets = [
    {
      subnet = "10.0.6.0/24"
      az     = "us-east-1d"
    },
    {
      subnet = "10.0.5.0/24"
      az     = "us-east-1e"
    },
    {
      subnet = "10.0.4.0/24"
      az     = "us-east-1f"
    }
  ]
  vpc_id                  = module.vpc.vpc_id
  map_public_ip_on_launch = false
}

# Public Route Table
module "public_rt" {
  source  = "./modules/vpc/route_tables"
  name    = "view-analytics-public-route-table"
  subnets = module.public_subnets.subnets[*]
  routes = [
    {
      cidr_block = "0.0.0.0/0"
      gateway_id = module.vpc.igw_id
    }
  ]
  vpc_id = module.vpc.vpc_id
}

# Private Route Table
module "private_rt" {
  source  = "./modules/vpc/route_tables"
  name    = "view-analytics-private-route-table"
  subnets = module.private_subnets.subnets[*]
  routes  = []
  vpc_id  = module.vpc.vpc_id
}

# EC2 IAM Instance Profile
data "aws_iam_policy_document" "instance_profile_assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "instance_profile_iam_role" {
  name               = "view-analytics-instance-profile-role"
  path               = "/"
  assume_role_policy = data.aws_iam_policy_document.instance_profile_assume_role.json
}

data "aws_iam_policy_document" "instance_profile_policy_document" {
  statement {
    effect    = "Allow"
    actions   = ["kinesis:*"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "instance_profile_s3_policy" {
  role   = aws_iam_role.instance_profile_iam_role.name
  policy = data.aws_iam_policy_document.instance_profile_policy_document.json
}

resource "aws_iam_instance_profile" "iam_instance_profile" {
  name = "view-analytics-iam-instance-profile"
  role = aws_iam_role.instance_profile_iam_role.name
}

module "view_analytics_frontend_instance" {
  source                      = "./modules/ec2"
  name                        = "view-analytics-frontend-instance"
  ami_id                      = data.aws_ami.ubuntu.id
  instance_type               = "t2.micro"
  key_name                    = "madmaxkeypair"
  associate_public_ip_address = true
  user_data                   = filebase64("${path.module}/scripts/user_data.sh")
  instance_profile            = aws_iam_instance_profile.iam_instance_profile.name
  subnet_id                   = module.public_subnets.subnets[0].id
  security_groups             = [module.security_group.id]
}

# S3 bucket for storing lambda function code
module "view_analytics_transform_function_code" {
  source      = "./modules/s3"
  bucket_name = "viewanalyticstransformfunctioncode"
  objects = [
    {
      key    = "lambda.zip"
      source = "./files/lambda.zip"
    }
  ]
  versioning_enabled = "Enabled"
  force_destroy      = true
}

# Lambda IAM  Role
module "view_analytics_transform_function_iam_role" {
  source             = "./modules/iam"
  role_name          = "view-analytics-lambda-function-iam-role"
  role_description   = "view-analytics-lambda-function-iam-role"
  policy_name        = "view-analytics-lambda-function-iam-policy"
  policy_description = "view-analytics-lambda-function-iam-policy"
  assume_role_policy = <<EOF
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Action": "sts:AssumeRole",
                "Principal": {
                  "Service": "lambda.amazonaws.com"
                },
                "Effect": "Allow",
                "Sid": ""
            }
        ]
    }
    EOF
  policy             = <<EOF
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Action": [
                  "logs:CreateLogGroup",
                  "logs:CreateLogStream",
                  "logs:PutLogEvents"
                ],
                "Resource": "arn:aws:logs:*:*:*",
                "Effect": "Allow"
            },
            {
                  "Effect": "Allow",
                  "Action": [
                    "kinesis:GetRecords",
                    "kinesis:GetShardIterator",
                    "kinesis:DescribeStream",
                    "kinesis:ListShards"
                  ],
                  "Resource": "*"
            }
        ]
    }
    EOF
}

# Lambda function module
module "view_analytics_transform_function" {
  source        = "./modules/lambda"
  function_name = "view-analytics-transform-function"
  role_arn      = module.view_analytics_transform_function_iam_role.arn
  #   env_variables = {
  #     SECRET_NAME = module.carshub_db_credentials.name
  #     DB_HOST     = tostring(split(":", module.carshub_db.endpoint)[0])
  #     DB_NAME     = var.db_name
  #     REGION      = var.region
  #   }
  handler   = "lambda.lambda_handler"
  timeout   = 60
  runtime   = "python3.12"
  s3_bucket = module.view_analytics_transform_function_code.bucket
  s3_key    = "lambda.zip"
}

# Kinesis module
module "view_analytics_kinesis_stream" {
  source           = "./modules/kinesis"
  name             = "view-analytics-stream"
  retention_period = 48
  shard_level_metrics = [
    "IncomingBytes",
    "OutgoingBytes",
  ]
  stream_mode = "ON_DEMAND"
}

# Opensearch module
module "opensearch" {
  source                          = "./modules/opensearch"
  domain_name                     = "opensearchdestination"
  engine_version                  = "OpenSearch_2.17"
  instance_type                   = "t3.small.search"
  instance_count                  = 1
  ebs_enabled                     = true
  volume_size                     = 10
  encrypt_at_rest_enabled         = true
  security_options_enabled        = true
  anonymous_auth_enabled          = true
  internal_user_database_enabled  = true
  master_user_name                = "mohit"
  master_user_password            = "Mohitdixit12345!"
  node_to_node_encryption_enabled = true
}

# Lambda IAM  Role
module "view_analytics_firehose_iam_role" {
  source             = "./modules/iam"
  role_name          = "view-analytics-firehose-iam-role"
  role_description   = "view-analytics-firehose-iam-role"
  policy_name        = "view-analytics-firehose-iam-policy"
  policy_description = "view-analytics-firehose-iam-policy"
  assume_role_policy = <<EOF
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Action": "sts:AssumeRole",
                "Principal": {
                  "Service": "firehose.amazonaws.com"
                },
                "Effect": "Allow",
                "Sid": ""
            }
        ]
    }
    EOF
  policy             = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "",
            "Effect": "Allow",
            "Action": [
                "s3:AbortMultipartUpload",
                "s3:GetBucketLocation",
                "s3:GetObject",
                "s3:ListBucket",
                "s3:ListBucketMultipartUploads",
                "s3:PutObject"
            ],
            "Resource": [
                "${module.view_analytics_opensearch_backup_bucket.arn}",
                "${module.view_analytics_opensearch_backup_bucket.arn}/*"
            ]
        },        
        {
            "Sid": "",
            "Effect": "Allow",
            "Action": [
                "lambda:InvokeFunction",
                "lambda:GetFunctionConfiguration"
            ],
            "Resource": "${module.view_analytics_transform_function.arn}:*"
        },        
        {
            "Sid": "",
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeVpcs",
                "ec2:DescribeVpcAttribute",
                "ec2:DescribeSubnets",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeNetworkInterfaces",
                "ec2:CreateNetworkInterface",
                "ec2:CreateNetworkInterfacePermission",
                "ec2:DeleteNetworkInterface"
            ],
            "Resource": "*"
        },
        {
            "Sid": "",
            "Effect": "Allow",
            "Action": [
                "es:DescribeElasticsearchDomain",
                "es:DescribeElasticsearchDomains",
                "es:DescribeElasticsearchDomainConfig",
                "es:ESHttpPost",
                "es:ESHttpPut"
            ],
            "Resource": [
                "${module.opensearch.domain_arn}",
                "${module.opensearch.domain_arn}/*"
            ]
        },
        {
            "Sid": "",
            "Effect": "Allow",
            "Action": [
                "es:ESHttpGet"
            ],
            "Resource": [
                "${module.opensearch.domain_arn}/_all/_settings",
                "${module.opensearch.domain_arn}/_cluster/stats",
                "${module.opensearch.domain_arn}/view-analytics-index/_mapping/%FIREHOSE_POLICY_TEMPLATE_PLACEHOLDER%",
                "${module.opensearch.domain_arn}/_nodes",
                "${module.opensearch.domain_arn}/_nodes/*/stats",
                "${module.opensearch.domain_arn}/_stats",
                "${module.opensearch.domain_arn}/view-analytics-index/_stats"
            ]
        },
        {
            "Sid": "",
            "Effect": "Allow",
            "Action": [
                "logs:PutLogEvents"
            ],
            "Resource": [
                "arn:aws:logs:us-east-1:577638377048:log-group:/aws/kinesisfirehose/KDS-OPS-vE2JU:log-stream:*",
                "arn:aws:logs:us-east-1:577638377048:log-group:%FIREHOSE_POLICY_TEMPLATE_PLACEHOLDER%:log-stream:*"
            ]
        },
        {
            "Sid": "",
            "Effect": "Allow",
            "Action": [
                "kinesis:DescribeStream",
                "kinesis:GetShardIterator",
                "kinesis:GetRecords",
                "kinesis:ListShards"
            ],
            "Resource": "${module.view_analytics_kinesis_stream.arn}"
        },
        {
            "Effect": "Allow",
            "Action": [
                "kms:Decrypt"
            ],
            "Resource": [
                "arn:aws:kms:us-east-1:577638377048:key/%FIREHOSE_POLICY_TEMPLATE_PLACEHOLDER%"
            ],
            "Condition": {
                "StringEquals": {
                    "kms:ViaService": "kinesis.us-east-1.amazonaws.com"
                },
                "StringLike": {
                    "kms:EncryptionContext:aws:kinesis:arn": "${module.view_analytics_kinesis_stream.arn}"
                }
            }
        }
    ]
}
    EOF
}

# S3 backup bucket for storing failed documents
module "view_analytics_opensearch_backup_bucket" {
  source             = "./modules/s3"
  bucket_name        = "viewanalyticsopensearchbackupbucket"
  versioning_enabled = "Enabled"
  force_destroy      = true
}

# Kinesis Data Firehose
module "firehose" {
  source                     = "./modules/firehose"
  name                       = "view-analytics-firehose"
  destination                = "opensearch"
  kinesis_stream_arn         = module.view_analytics_kinesis_stream.arn
  kinesis_stream_role_arn    = module.view_analytics_firehose_iam_role.arn
  opensearch_domain_arn      = module.opensearch.domain_arn
  opensearch_role_arn        = module.view_analytics_firehose_iam_role.arn
  opensearch_index_name      = "view-analytics-index"
  processing_enabled         = true
  backup_bucket_arn          = module.view_analytics_opensearch_backup_bucket.arn
  s3_compression_format      = "GZIP"
  s3_role_arn                = module.view_analytics_firehose_iam_role.arn
  processing_type            = "Lambda"
  processing_parameter_name  = "LambdaArn"
  processing_parameter_value = module.view_analytics_transform_function.arn
}
