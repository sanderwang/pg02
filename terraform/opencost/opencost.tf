data "aws_eks_cluster" "this" {
  name = "eks-playground"
}

data "aws_iam_openid_connect_provider" "this" {
  url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_s3_bucket" "opencost-spot-feed" {
  bucket = "pg02-spot-feed"
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
