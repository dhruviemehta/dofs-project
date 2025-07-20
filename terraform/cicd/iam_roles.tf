# Simple CI/CD setup for GitHub integration
# This creates the essential pipeline without complex event triggers

# S3 bucket for CodePipeline artifacts
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "codepipeline_artifacts" {
  bucket = "${var.project_name}-${var.environment}-pipeline-artifacts-${random_id.bucket_suffix.hex}"
}

resource "aws_s3_bucket_versioning" "codepipeline_artifacts" {
  bucket = aws_s3_bucket.codepipeline_artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "codepipeline_artifacts" {
  bucket = aws_s3_bucket.codepipeline_artifacts.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "codepipeline_artifacts" {
  bucket                  = aws_s3_bucket.codepipeline_artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CodeBuild IAM Role
resource "aws_iam_role" "codebuild_role" {
  name = "${var.project_name}-${var.environment}-codebuild-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })
}

# CodeBuild policies - UPDATED WITH MISSING PERMISSIONS
resource "aws_iam_role_policy" "codebuild_policy" {
  role = aws_iam_role.codebuild_role.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:GetBucketAcl",
          "s3:GetBucketLocation",
          "s3:ListBucket"
        ]
        Resource = [
          "${aws_s3_bucket.codepipeline_artifacts.arn}",
          "${aws_s3_bucket.codepipeline_artifacts.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:*"
        ]
        Resource = [
          "arn:aws:s3:::dofs-terraform-state-4aa0782d",
          "arn:aws:s3:::dofs-terraform-state-4aa0782d/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
          "dynamodb:DescribeTable",
          "dynamodb:CreateTable",
          "dynamodb:UpdateTable",
          "dynamodb:TagResource",
          "dynamodb:UntagResource",
          "dynamodb:ListTagsOfResource",
          "dynamodb:DescribeContinuousBackups",
          "dynamodb:DescribeTimeToLive",
          "dynamodb:DescribeBackup",
          "dynamodb:ListBackups"
        ]
        Resource = [
          "arn:aws:dynamodb:${var.aws_region}:*:table/dofs-terraform-locks",
          "arn:aws:dynamodb:${var.aws_region}:*:table/dofs-*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:*",
          "lambda:GetEventSourceMapping"
        ]
        Resource = [
          "arn:aws:lambda:${var.aws_region}:*:function:dofs-*",
          "arn:aws:lambda:${var.aws_region}:*:event-source-mapping:*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "apigateway:*"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:*"
        ]
        Resource = [
          "arn:aws:sqs:${var.aws_region}:*:dofs-*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sns:*"
        ]
        Resource = [
          "arn:aws:sns:${var.aws_region}:*:dofs-*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "states:*"
        ]
        Resource = [
          "arn:aws:states:${var.aws_region}:*:stateMachine:dofs-*",
          "arn:aws:states:${var.aws_region}:*:execution:dofs-*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:*",
          "logs:*"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "iam:GetRole",
          "iam:GetRolePolicy",
          "iam:GetPolicy",
          "iam:GetPolicyVersion",
          "iam:ListPolicyVersions",
          "iam:ListRolePolicies",
          "iam:ListAttachedRolePolicies",
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:PutRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:CreatePolicy",
          "iam:DeletePolicy",
          "iam:UpdateRole",
          "iam:UpdateAssumeRolePolicy",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:PassRole"
        ]
        Resource = [
          "arn:aws:iam::*:role/dofs-*",
          "arn:aws:iam::*:policy/dofs-*"
        ]
      }
    ]
  })
}


# CodePipeline IAM Role
resource "aws_iam_role" "codepipeline_role" {
  name = "${var.project_name}-${var.environment}-codepipeline-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  role = aws_iam_role.codepipeline_role.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketAcl",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.codepipeline_artifacts.arn,
          "${aws_s3_bucket.codepipeline_artifacts.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild"
        ]
        Resource = aws_codebuild_project.terraform_deploy.arn
      }
    ]
  })
}

