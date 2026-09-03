data "aws_eks_cluster" "this" {
  name = "eks-playground"
}

data "aws_iam_openid_connect_provider" "this" {
  url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_s3_bucket" "opencost-spot-feed" {
  bucket = "472882997329-pg02-spot-feed"
}

resource "aws_s3_bucket_ownership_controls" "opencost-spot-feed" {
  bucket = aws_s3_bucket.opencost-spot-feed.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_spot_datafeed_subscription" "opencost" {
  bucket = aws_s3_bucket.opencost-spot-feed.bucket
  prefix = "spot-feed"

  depends_on = [aws_s3_bucket_ownership_controls.opencost-spot-feed]
}

resource "aws_s3_bucket" "opencost-cur" {
  bucket = "472882997329-pg02-cur"
}

data "aws_iam_policy_document" "opencost-cur-bucket" {
  statement {
    effect    = "Allow"
    actions   = ["s3:GetBucketAcl", "s3:GetBucketPolicy"]
    resources = [aws_s3_bucket.opencost-cur.arn]

    principals {
      type        = "Service"
      identifiers = ["billingreports.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = ["472882997329"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = ["arn:aws:cur:us-east-1:472882997329:definition/*"]
    }
  }

  statement {
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.opencost-cur.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["billingreports.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = ["472882997329"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = ["arn:aws:cur:us-east-1:472882997329:definition/*"]
    }
  }
}

resource "aws_s3_bucket_policy" "opencost-cur" {
  bucket = aws_s3_bucket.opencost-cur.id
  policy = data.aws_iam_policy_document.opencost-cur-bucket.json
}

resource "aws_cur_report_definition" "opencost" {
  provider = aws.billing

  report_name                = "pg02-cur"
  time_unit                  = "HOURLY"
  format                     = "Parquet"
  compression                = "Parquet"
  additional_schema_elements = ["RESOURCES"]
  additional_artifacts       = ["ATHENA"]
  report_versioning          = "OVERWRITE_REPORT"
  refresh_closed_reports     = true
  s3_bucket                  = aws_s3_bucket.opencost-cur.bucket
  s3_prefix                  = "cur"
  s3_region                  = "us-west-2"

  depends_on = [aws_s3_bucket_policy.opencost-cur]
}

resource "aws_glue_catalog_database" "opencost-cur" {
  name = "pg02_cur"
}

resource "aws_iam_role" "opencost-glue" {
  name = "pg02-opencost-glue"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "glue.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "opencost-glue" {
  role       = aws_iam_role.opencost-glue.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy" "opencost-glue-s3" {
  name = "cur-s3-access"
  role = aws_iam_role.opencost-glue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = aws_s3_bucket.opencost-cur.arn
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject"]
        Resource = "${aws_s3_bucket.opencost-cur.arn}/*"
      },
    ]
  })
}

resource "aws_glue_crawler" "opencost-cur" {
  name          = "pg02-cur"
  database_name = aws_glue_catalog_database.opencost-cur.name
  role          = aws_iam_role.opencost-glue.arn
  schedule      = "cron(0 1 * * ? *)"

  s3_target {
    path       = "s3://${aws_s3_bucket.opencost-cur.bucket}/cur/pg02-cur/pg02-cur"
    exclusions = ["**.json", "**.zip", "**.gz"]
  }

  schema_change_policy {
    delete_behavior = "LOG"
    update_behavior = "LOG"
  }
}

resource "aws_athena_workgroup" "opencost" {
  name = "pg02-opencost"

  configuration {
    result_configuration {
      output_location = "s3://${aws_s3_bucket.opencost-cur.bucket}/athena"
    }
  }
}

data "aws_iam_policy_document" "opencost-trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.this.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${data.aws_iam_openid_connect_provider.this.url}:sub"
      values   = ["system:serviceaccount:telemetry:opencost"]
    }

    condition {
      test     = "StringEquals"
      variable = "${data.aws_iam_openid_connect_provider.this.url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "opencost-access" {
  statement {
    effect    = "Allow"
    actions   = ["ec2:DescribeSpotPriceHistory", "pricing:GetProducts"]
    resources = ["*"]
  }

  statement {
    effect    = "Allow"
    actions   = ["s3:HeadBucket", "s3:ListBucket"]
    resources = [aws_s3_bucket.opencost-spot-feed.arn]
  }

  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:HeadObject"]
    resources = ["${aws_s3_bucket.opencost-spot-feed.arn}/*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "athena:GetQueryExecution",
      "athena:GetQueryResults",
      "athena:GetWorkGroup",
      "athena:StartQueryExecution",
      "athena:StopQueryExecution",
    ]
    resources = [aws_athena_workgroup.opencost.arn]
  }

  statement {
    effect    = "Allow"
    actions   = ["glue:GetDatabase"]
    resources = [
      "arn:aws:glue:us-west-2:472882997329:catalog",
      aws_glue_catalog_database.opencost-cur.arn,
    ]
  }

  statement {
    effect  = "Allow"
    actions = [
      "glue:BatchGetPartition",
      "glue:GetPartition",
      "glue:GetPartitions",
      "glue:GetTable",
    ]
    resources = [
      "arn:aws:glue:us-west-2:472882997329:catalog",
      aws_glue_catalog_database.opencost-cur.arn,
      "arn:aws:glue:us-west-2:472882997329:table/pg02_cur/pg02_cur",
    ]
  }

  statement {
    effect    = "Allow"
    actions   = ["s3:GetBucketLocation", "s3:ListBucket", "s3:ListBucketMultipartUploads"]
    resources = [aws_s3_bucket.opencost-cur.arn]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:AbortMultipartUpload",
      "s3:GetObject",
      "s3:ListMultipartUploadParts",
      "s3:PutObject",
    ]
    resources = ["${aws_s3_bucket.opencost-cur.arn}/*"]
  }
}

resource "aws_iam_role" "opencost" {
  name               = "pg02-opencost"
  assume_role_policy = data.aws_iam_policy_document.opencost-trust.json
}

resource "aws_iam_role_policy" "opencost-access" {
  name   = "pricing-access"
  role   = aws_iam_role.opencost.id
  policy = data.aws_iam_policy_document.opencost-access.json
}
