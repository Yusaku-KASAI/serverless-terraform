# Chatbot Module (Terraform)

このディレクトリは **AWS Chatbot（Slack 連携）を Terraform で構築・管理するためのモジュール** です。

SNS Topic からの通知を Slack に流し、CloudWatch アラーム → SNS → Chatbot → Slack という監視フローを簡単に構築できます。
ChatOps コマンドは一切許可せず、**通知専用（権限 deny-all）** として利用します。

他のモジュール（例：Lambda、API Gateway）のアラーム SNS Topic と組み合わせることで、
**サーバーレスアーキテクチャの監視を完全 IaC 化するための基盤** となります。

---

## 📌 目的

AWS Chatbot の構築・管理をリポジトリ横断で統一し、
監視アラートの Slack 通知を標準化するために設計された Terraform モジュールです。

### このモジュールが解決する主なポイント

* CloudWatch アラームの Slack 通知を Terraform で自動化し、手動設定を排除
* 複数の SNS Topic を一つの Slack チャンネルに集約し、監視を一元管理
* ChatOps コマンドを完全に無効化し、セキュリティリスクを最小化
* プロジェクト単位で Chatbot を簡単に量産できる命名規則を提供

---

## 📁 構成

```
modules/
  chatbot/
    chatbot.tf     # Slack チャンネルと紐付いた Chatbot Configuration
    iam.tf         # Chatbot 用 IAM Role と guardrail（deny-all）ポリシー
    variables.tf   # 入力変数
    outputs.tf     # 出力値
    README.md      # このファイル
```

---

## 📝 設計ポリシー

### 基本方針

* **通知専用の Chatbot** として利用する前提
  - IAM ポリシーは `Deny *:*` をアタッチし、ChatOps のコマンド実行は完全に防止
  - セキュリティリスクを最小化し、通知機能に特化
* 複数の SNS Topic を 1 つの Slack チャンネルへ集約可能
  - 監視用 SNS（例：Lambda モジュールのアラーム）を束ねる用途を想定
  - マイクロサービス単位のアラームを 1 つのチャンネルで一元管理
* 名前付けは `project` をベースに自動生成可能
  - プロジェクト単位の Chatbot を簡単に量産できる
  - 明示的な命名も可能で柔軟性を確保

### モジュールの制約・設計方針

このモジュールは、セキュリティを重視した通知専用の設計になっています。以下の制約を理解した上でご利用ください。

#### Slack チャンネルとの対応

* **モジュール一つにつき Slack チャンネル一つ**
  - 複数の Slack チャンネルに通知する場合は、モジュールを複数作成
  - チャンネルごとに通知する SNS Topic を変えることで、アラートの種類を分離可能

#### 通知専用の制約

* **ChatOps コマンドは完全に無効化（Guardrail: deny-all）**
  - Slack から AWS リソースを操作することは不可
  - セキュリティリスクを最小化するため、通知機能のみに特化
  - Guardrail ポリシーで全ての AWS API アクションを Deny

**Guardrail ポリシーの内容：**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Deny",
      "Action": "*",
      "Resource": "*"
    }
  ]
}
```

#### 事前準備が必要

* **Slack Workspace ID と Channel ID は事前設定が必要**
  - AWS Console で Slack Workspace と AWS Chatbot の連携を事前に実施
  - Slack チャンネルを作成し、Channel ID を取得
  - これらの情報を変数として渡す

#### SNS Topic の管理

* **SNS Topic 本体はこのモジュールでは管理しない**
  - Lambda モジュールや API Gateway モジュールで作成された SNS Topic の ARN を受け取る
  - 複数の SNS Topic を一つの Slack チャンネルに集約可能

#### 命名規則

* **Configuration Name は自動生成または明示指定**
  - `configuration_name` 未指定時は `${project}-chatbot-slack` が自動生成
  - 明示指定も可能で、プロジェクト固有の命名規則に対応

#### IAM Role の信頼ポリシー

* **`chatbot.amazonaws.com` からの AssumeRole のみを許可**
  - 他のサービスからの Assume を防止

---

## 🏷 管理範囲

### ✔ 管理する（このモジュールで作成される）

#### Chatbot Configuration
* **`aws_chatbot_slack_channel_configuration`**
  - Slack ワークスペース ID（`slack_team_id`）と AWS Chatbot の紐付け
  - Slack チャンネル ID（`slack_channel_id`）への通知配信設定
  - 複数の SNS Topic からの通知を 1 つのチャンネルに集約可能
  - Guardrail ポリシーによる権限制御

#### IAM
* **`aws_iam_role.chatbot_slack_role`**
  - AWS Chatbot が Assume する IAM Role
  - 信頼ポリシー: `chatbot.amazonaws.com` からの AssumeRole を許可
* **`aws_iam_policy.chatbot_slack_deny_all`**
  - すべての AWS API アクションを Deny（`Action: "*"`, `Effect: "Deny"`）
  - **通知専用**として運用し、ChatOps コマンドの実行を完全に防止
  - Guardrail ポリシーとして Chatbot Configuration にアタッチ

### ✖ 管理しない（外部で管理）

| リソース | 理由 |
|---------|------|
| **Slack App の設定** | AWS Console で Slack Workspace と AWS Chatbot の連携を事前に実施する必要がある |
| **SNS Topic 本体** | Lambda モジュールなどで作られる監視用 SNS Topic を ARN で受け取る |
| **Slack Channel の作成** | Slack 側で事前にチャンネルを作成し、Channel ID を取得する |

---

## 📋 変数（Variables）

### 必須変数（実質）

以下の変数は、デフォルト値が空文字列ですが、**実質的に必須**です。

| 変数名 | 型 | 説明 |
|--------|---|------|
| `slack_team_id` | `string` | 通知先 Slack Workspace ID（例: `TXXXXXXXX`）<br>AWS Console で Slack 連携時に取得 |
| `slack_channel_id` | `string` | 通知先 Slack Channel ID（例: `CYYYYYYYY`）<br>Slack チャンネルの詳細画面から取得 |

### Chatbot 設定

| 変数名 | 型 | デフォルト | 説明 |
|--------|---|-----------|------|
| `configuration_name` | `string` | `""` | Chatbot 設定名<br>未指定時は `${project}-chatbot-slack` が自動生成される |
| `sns_topic_arns` | `list(string)` | `[]` | この Chatbot に通知する SNS Topic の ARN リスト<br>複数の SNS Topic を 1 つの Slack チャンネルに集約可能 |

### メタ情報

| 変数名 | 型 | デフォルト | 説明 |
|--------|---|-----------|------|
| `project` | `string` | `""` | プロジェクト識別子<br>`configuration_name` 未指定時の名前生成に使用 |
| `tags` | `map(any)` | `{}` | リソースに付与するタグ |

---

## 🧪 使用例（Usage Examples）

### 前提条件

このモジュールを使用する前に、以下の設定が必要です：

1. **AWS Console で Slack との連携設定**
   - AWS Console → AWS Chatbot → Configure new client
   - Slack Workspace を選択して連携
   - 連携後、Workspace ID（`slack_team_id`）を取得

2. **Slack での準備**
   - 通知先の Slack チャンネルを作成
   - チャンネル ID（`slack_channel_id`）を取得
     - チャンネルを右クリック → チャンネル詳細を表示 → 最下部の「チャンネル ID」

### 基本的な使用例：Lambda アラームを Slack に通知

```hcl
module "lambda_example" {
  source = "./modules/lambda"

  project             = "sample"
  function_name       = "payment-worker"
  ecr_repository_name = "payment-worker"

  # ... 省略 ...

  # この Lambda モジュール内で SNS Topic (alarm) が作られている想定
}

module "chatbot_alarm" {
  source = "./modules/chatbot"

  project = "sample"

  # Slack ワークスペース / チャンネルは事前に AWS Chatbot 連携済みのもの
  slack_team_id    = "TXXXXXXXX"     # WorkSpace ID
  slack_channel_id = "CYYYYYYYY"     # Channel ID

  # Lambda モジュールから出力されたアラーム SNS Topic を紐付け
  sns_topic_arns = [
    module.lambda_example.alarm_sns_topic_arn,
  ]

  tags = {
    Project = "sample"
    Env     = "prod"
  }
}
```

### 複数の Lambda アラームを 1 つの Slack チャンネルに集約

```hcl
module "lambda_payment" {
  source = "./modules/lambda"

  project             = "sample"
  function_name       = "payment-worker"
  ecr_repository_name = "payment-worker"
}

module "lambda_order" {
  source = "./modules/lambda"

  project             = "sample"
  function_name       = "order-processor"
  ecr_repository_name = "order-processor"
}

module "lambda_notification" {
  source = "./modules/lambda"

  project             = "sample"
  function_name       = "notification-sender"
  ecr_repository_name = "notification-sender"
}

# すべての Lambda アラームを 1 つの Slack チャンネルに集約
module "chatbot_all_alarms" {
  source = "./modules/chatbot"

  project = "sample"

  slack_team_id    = "TXXXXXXXX"
  slack_channel_id = "CYYYYYYYY"  # #alerts チャンネル

  sns_topic_arns = [
    module.lambda_payment.alarm_sns_topic_arn,
    module.lambda_order.alarm_sns_topic_arn,
    module.lambda_notification.alarm_sns_topic_arn,
  ]

  tags = {
    Project = "sample"
    Env     = "prod"
  }
}
```

### 環境ごとに Slack チャンネルを分ける

```hcl
# 本番環境のアラームは #prod-alerts へ
module "chatbot_prod" {
  source = "./modules/chatbot"

  project = "sample"

  slack_team_id    = "TXXXXXXXX"
  slack_channel_id = "CPRODXXXX"  # #prod-alerts

  sns_topic_arns = [
    module.lambda_prod_payment.alarm_sns_topic_arn,
    module.lambda_prod_order.alarm_sns_topic_arn,
  ]

  tags = {
    Project = "sample"
    Env     = "prod"
  }
}

# 開発環境のアラームは #dev-alerts へ
module "chatbot_dev" {
  source = "./modules/chatbot"

  project = "sample"

  slack_team_id    = "TXXXXXXXX"
  slack_channel_id = "CDEVXXXXX"  # #dev-alerts

  sns_topic_arns = [
    module.lambda_dev_payment.alarm_sns_topic_arn,
    module.lambda_dev_order.alarm_sns_topic_arn,
  ]

  tags = {
    Project = "sample"
    Env     = "dev"
  }
}
```

### Configuration Name を明示的に指定

```hcl
module "chatbot_custom_name" {
  source = "./modules/chatbot"

  project = "sample"

  # Configuration Name を明示的に指定
  configuration_name = "my-custom-chatbot-config"

  slack_team_id    = "TXXXXXXXX"
  slack_channel_id = "CYYYYYYYY"

  sns_topic_arns = [
    module.lambda_example.alarm_sns_topic_arn,
  ]
}
```

---

## 📤 出力（Outputs）

### Chatbot Configuration

| Output 名 | 説明 |
|----------|------|
| `configuration_name` | 作成された Chatbot Slack channel configuration 名 |
| `chatbot_slack_channel_arn` | Chatbot Slack channel configuration の ARN |

### IAM

| Output 名 | 説明 |
|----------|------|
| `iam_role_arn` | Chatbot が Assume する IAM Role の ARN |
| `guardrail_policy_arn` | Chatbot 用 guardrail（deny all）ポリシー ARN |

### Slack 情報

| Output 名 | 説明 |
|----------|------|
| `slack_team_id` | 設定に紐づく Slack Workspace ID |
| `slack_channel_id` | 設定に紐づく Slack Channel ID |
| `slack_team_name` | 設定に紐づく Slack Workspace 名（AWS が自動取得） |
| `slack_channel_name` | 設定に紐づく Slack Channel 名（AWS が自動取得） |

### SNS Topic

| Output 名 | 説明 |
|----------|------|
| `sns_topic_arns` | Chatbot に紐付けた SNS Topic の ARN 一覧 |

### 使用例

```hcl
# 作成された Chatbot の設定を確認
output "chatbot_config" {
  value = {
    name          = module.chatbot_alarm.configuration_name
    arn           = module.chatbot_alarm.chatbot_slack_channel_arn
    slack_team    = module.chatbot_alarm.slack_team_name
    slack_channel = module.chatbot_alarm.slack_channel_name
  }
}

# 監査用に SNS Topic の紐付けを確認
output "monitored_sns_topics" {
  value = module.chatbot_alarm.sns_topic_arns
}

# 他のモジュールで Chatbot ARN を参照（EventBridge Rule のターゲットなど）
resource "aws_cloudwatch_event_target" "chatbot" {
  rule = aws_cloudwatch_event_rule.example.name
  arn  = module.chatbot_alarm.chatbot_slack_channel_arn
}
```

---

## 🔗 関連モジュール

> ※ 各モジュールの詳細は、それぞれの README を参照してください。

### 実装済みモジュール

* **`lambda`** ✅
  - CloudWatch アラーム + SNS Topic を自動作成
  - Lambda のエラー、スロットル、メモリ使用率などを監視
  - Chatbot モジュールと組み合わせて Slack 通知を実現
  - 詳細: [modules/lambda/README.md](../lambda/README.md)

* **`apigateway`** ✅
  - API Gateway 単位のアラーム（レイテンシ、エラー率など）を SNS に送信
  - Chatbot で API の異常を Slack 通知
  - 詳細: [modules/apigateway/README.md](../apigateway/README.md)

### 未実装モジュール

* **`stepfunctions`** 🔄
  - Step Functions ステートマシンのアラーム（実行失敗、タイムアウトなど）を SNS に送信
  - Chatbot でワークフローの異常を Slack 通知

---

## 📚 参考リンク

- [AWS Chatbot 公式ドキュメント](https://docs.aws.amazon.com/chatbot/latest/adminguide/what-is.html)
- [Terraform AWS Chatbot Slack Channel Configuration](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/chatbot_slack_channel_configuration)
- [Slack Channel ID の取得方法](https://slack.com/intl/ja-jp/help/articles/221769328-Slack-%E3%83%81%E3%83%A3%E3%83%B3%E3%83%8D%E3%83%AB%E3%81%AE-ID-%E3%82%92%E8%A6%8B%E3%81%A4%E3%81%91%E3%82%8B)

---
