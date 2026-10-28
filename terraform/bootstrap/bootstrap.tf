data "aws_iam_policy_document" "tf-runner-trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["*"]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:PrincipalArn"
      values   = ["arn:aws:iam::472882997329:role/kubenuts/pg02/*"]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:PrincipalTag/kubenuts/assumes"
      values   = ["tf-runner"]
    }
  }

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::472882997329:user/sander.wang@narvar.com"]
    }
  }
}

resource "aws_iam_role" "tf-runner" {
  name               = "pg02-kubenuts-tf"
  path               = "/kubenuts/pg02/"
  assume_role_policy = data.aws_iam_policy_document.tf-runner-trust.json
}

data "aws_iam_policy_document" "tf-runner-operations" {
  statement {
    sid    = "Operations"
    effect = "Allow"
    actions = [
      "athena:*",
      "cur:*",
      "ec2:CreateSpotDatafeedSubscription",
      "ec2:DeleteSpotDatafeedSubscription",
      "ec2:DescribeSpotDatafeedSubscription",
      "eks:DescribeCluster",
      "elasticloadbalancing:Describe*",
      "glue:*",
      "iam:*",
      "route53:*",
      "s3:*",
      "secretsmanager:*",
      "wafv2:*",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "tf-runner-operations" {
  name   = "tf-runner-operations"
  role   = aws_iam_role.tf-runner.id
  policy = data.aws_iam_policy_document.tf-runner-operations.json
}

output "tf_runner_role_arn" {
  value = aws_iam_role.tf-runner.arn
}
