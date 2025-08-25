resource "aws_ecr_repository" "ecr" {
  name                 = var.repository_name
  force_delete         = var.force_delete
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = var.image_scan_on_push
  }

  # Додаткові/кастомні теги можна злити через merge
  tags = merge(
    {
      Name = var.repository_name
    },
    try(var.tags, {})
  )
}

data "aws_caller_identity" "current" {}

# Base in-account push/pull policy

data "aws_iam_policy_document" "in_account" {
  statement {
    sid    = "AllowPushPullWithinAccount"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }

    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload"
    ]
  }
}

data "aws_iam_policy_document" "cross_account_pull" {
  count = length(var.allowed_principals) > 0 ? 1 : 0

  statement {
    sid    = "AllowCrossAccountPull"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = var.allowed_principals
    }

    actions = [
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:BatchCheckLayerAvailability"
    ]
  }
}

data "aws_iam_policy_document" "final" {
  source_policy_documents = compact([
    data.aws_iam_policy_document.in_account.json,
    length(var.allowed_principals) > 0 ? data.aws_iam_policy_document.cross_account_pull[0].json : null
  ])

  # Просто умова, що повертає список
  override_policy_documents = var.repository_policy != null ? [var.repository_policy] : []
}


resource "aws_ecr_repository_policy" "ecr_policy" {
  repository = aws_ecr_repository.ecr.name
  policy     = data.aws_iam_policy_document.final.json
}