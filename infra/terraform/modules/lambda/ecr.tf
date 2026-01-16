locals {
  # image_tag が既存のパターンでカバーされているかチェック
  image_tag_is_latest  = var.image_tag == "latest"
  image_tag_is_release = can(regex("^release.*", var.image_tag))
  image_tag_is_covered = local.image_tag_is_latest || local.image_tag_is_release
}

resource "aws_ecr_repository" "this" {
  name                 = var.ecr_repository_name
  image_tag_mutability = "IMMUTABLE_WITH_EXCLUSION"

  image_scanning_configuration {
    scan_on_push = true
  }

  image_tag_mutability_exclusion_filter {
    filter      = "latest"
    filter_type = "WILDCARD"
  }

  image_tag_mutability_exclusion_filter {
    filter      = "release*"
    filter_type = "WILDCARD"
  }

  # image_tag が既存パターンでカバーされていない場合、追加で保護
  dynamic "image_tag_mutability_exclusion_filter" {
    for_each = local.image_tag_is_covered ? [] : [1]
    content {
      filter      = var.image_tag
      filter_type = "WILDCARD"
    }
  }

  tags = merge(var.tags, {
    Name = var.ecr_repository_name
  })
}

data "aws_iam_policy_document" "ecr_pull" {
  statement {
    sid = "ECRRepositoryPolicy"

    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = [
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:SetRepositoryPolicy",
      "ecr:DeleteRepositoryPolicy",
      "ecr:GetRepositoryPolicy",
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:sourceArn"
      values   = ["arn:aws:lambda:${data.aws_region.current.name}:${data.aws_caller_identity.self.account_id}:function:*"]
    }
  }
}

resource "aws_ecr_repository_policy" "this" {
  repository = aws_ecr_repository.this.name

  policy = data.aws_iam_policy_document.ecr_pull.json
}

resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name

  # 参考：https://docs.aws.amazon.com/ja_jp/AmazonECR/latest/userguide/lifecycle_policy_examples.html#lp_example_multiple
  policy = jsonencode({
    rules = concat(
      [
        {
          # ルール1: latestタグは最新1つを保持（2つ目以降を削除）
          rulePriority = 1,
          description  = "Keep only 1 latest tag",
          selection = {
            tagStatus      = "tagged",
            tagPatternList = ["latest"],
            countType      = "imageCountMoreThan",
            countNumber    = 1
          },
          action = {
            type = "expire"
          }
        },
        {
          # ルール2: release*タグは最新10個を保持（11個目以降を削除）
          rulePriority = 2,
          description  = "Keep last 10 release tags",
          selection = {
            tagStatus      = "tagged",
            tagPatternList = ["release*"],
            countType      = "imageCountMoreThan",
            countNumber    = 10
          },
          action = {
            type = "expire"
          }
        },
      ],
      # image_tag が既存パターンでカバーされていない場合、追加で保護
      local.image_tag_is_covered ? [] : [
        {
          rulePriority = 3,
          description  = "Keep only 1 ${var.image_tag} tag",
          selection = {
            tagStatus      = "tagged",
            tagPatternList = [var.image_tag],
            countType      = "imageCountMoreThan",
            countNumber    = 1
          },
          action = {
            type = "expire"
          }
        }
      ],
      [
        {
          # ルール: untaggedイメージは1日で削除
          rulePriority = 10,
          description  = "Remove untagged images after 1 day",
          selection = {
            tagStatus   = "untagged",
            countType   = "sinceImagePushed",
            countUnit   = "days",
            countNumber = 1
          },
          action = {
            type = "expire"
          }
        },
        {
          # ルール: その他の全イメージは90日で削除
          # （ルール1,2,3で保護されたタグは除外される）
          rulePriority = 20,
          description  = "Expire other images older than 90 days",
          selection = {
            tagStatus   = "any",
            countType   = "sinceImagePushed",
            countUnit   = "days",
            countNumber = 90
          },
          action = {
            type = "expire"
          }
        }
      ]
    )
  })
}
