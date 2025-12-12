# Lambda Module (Terraform)

このディレクトリは **AWS Lambda を Terraform で構築・管理するためのモジュール** です。
ECR、IAM、CloudWatch、イベントトリガー（EventBridge / SNS / SQS）など、
Lambda 運用に必要なリソースを包括的に作成します。

他のモジュール（例：API Gateway、Step Functions、Chatbot）と連携して
**サーバーレスアーキテクチャを完全 IaC 化するための基盤** となります。

---

## 📌 目的

Lambda の作成・更新・管理をリポジトリ横断で統一し、
従来の Serverless Framework 運用にあった課題を解決するために設計された Terraform モジュールです。

### このモジュールが解決する主なポイント

* Lambda の構成・監視・イベント設定をすべて Terraform 化し、コピペ文化・属人化を解消
* コンテナイメージ（ECR）での Lambda デプロイを標準化
* Lambda に必要な周辺リソース（IAM / Logs / Alarms / Event Sources）を一括構築
* サーバーレスアーキテクチャ全体を Terraform Modules によって疎結合に設計しやすくする

---

## 📁 構成

```
modules/
  lambda/
    lambda.tf              # Lambda 本体、再帰実行設定、Invoke Config
    iam.tf                 # Lambda 実行ロール・基本ポリシー設定
    iam_destination.tf     # DLQ / Destination 用の IAM ポリシー設定
    ecr.tf                 # ECR リポジトリ
    cloudwatch.tf          # LogGroup、MetricFilter、アラーム、SNS Topic
    security_group.tf      # VPC 用デフォルト Security Group（条件付き作成）
    event_schedule.tf      # EventBridge スケジュールトリガー
    event_sns.tf           # SNS → Lambda トリガー
    event_sqs.tf           # SQS → Lambda イベントソースマッピング + IAM
    variables.tf           # 入力変数
    outputs.tf             # 出力値
    README.md              # このファイル
```

---

## 📝 設計ポリシー

### 基本方針

* Lambda の「構築」「実行環境」「監視」「イベント」までを一括提供し、**再利用性と統一性を最大化**
* Event Source の境界は「依存関係の上下関係」で区分
  - 例：SNS/SQS のような "汎用メッセージ基盤" → Lambda にトリガー設定 **する**
  - 例：API Gateway / Step Functions のような "Lambda の上層" → トリガー設定 **しない**
* Lambda のコードデプロイは ECR コンテナイメージに統一することで起動高速化と CI/CD 連携を容易に
* Serverless Framework を廃止し Terraform 管理に一本化するための基盤となる

### モジュールの制約・設計方針

このモジュールは、Lambda 関数の標準的な運用パターンを実現するための設計になっています。以下の制約を理解した上でご利用ください。

#### Lambda 関数とリソースの対応

* **モジュール一つにつき Lambda 関数は一つ**
  - 複数の Lambda 関数を管理する場合は、モジュールを複数作成
  - マイクロサービスごとにモジュールを分けることを推奨

* **ECR リポジトリも一つ（Lambda 関数に1対1対応）**
  - 各 Lambda 関数専用の ECR リポジトリを作成
  - イメージタグで Lambda のバージョンを管理

* **アラーム用 SNS Topic は関数ごとに一つ**
  - Lambda 関数ごとに専用の SNS Topic を作成
  - 複数の Lambda アラームを一つの Slack チャンネルに集約する場合は、Chatbot モジュール側で設定

#### パッケージタイプ

* **コンテナイメージのみ対応**
  - ZIP 形式のデプロイは未対応
  - レイヤーは未対応
  - 起動速度と依存関係管理の観点からコンテナイメージを推奨

#### ログ設定

* **JSON ログ形式固定**
  - `log_format = "JSON"` で CloudWatch Logs Insights での分析を容易に
  - テキスト形式への変更は未対応
  - ログレベルは `INFO` 固定（Application / System）

#### Lambda Insights

* **Lambda Insights は自動有効化**
  - `CloudWatchLambdaInsightsExecutionRolePolicy` を自動アタッチ
  - Docker イメージに Lambda Insights Extension を含める必要あり
  - 詳細なメトリクス（メモリ、CPU、ネットワークなど）を取得

#### メモリ使用率の監視

* **CloudWatch Metric Math でメモリ使用率を算出**
  - `MaxMemoryUsed / MemorySize * 100` の計算により、OOM のリスクを事前検知
  - メモリ使用率アラームで閾値を超えた場合に通知

#### Fail Fast 設定

* **Event Invoke Config は fail fast 固定**
  - `maximum_retry_attempts = 0`（リトライなし）
  - `maximum_event_age_in_seconds = 60`（60秒で破棄）
  - 長時間のリトライを避け、Destination で即座にエラーハンドリング

#### 再帰実行の防止

* **再帰実行は Terminate 固定**
  - `recursive_loop = "Terminate"` で無限ループを防止
  - Lambda が自身を呼び出すことを検知して停止

#### X-Ray トレーシング

* **X-Ray はオプション（デフォルト: PassThrough）**
  - `use_xray = true` で Active モード
  - `use_xray = false` で PassThrough モード（デフォルト）
  - Active モード時は `AWSXRayDaemonWriteAccess` を自動アタッチ

#### 同時実行数の制御

* **`reserved_concurrent_executions` で制限可能**
  - デフォルトは `-1`（無制限）
  - コスト制御や外部 API のレート制限対策に有効

#### Event Source の管理範囲

* **EventBridge Schedule / SNS / SQS のトリガーを管理**
  - 下位層のメッセージ基盤からのトリガーを設定
  - API Gateway / Step Functions のトリガーは上位モジュールで管理

* **S3 トリガーは非推奨**
  - S3 は1通知設定しか持てないため、SNS 経由を推奨
  - 柔軟性とメンテナンス性の観点から SNS 経由が望ましい

#### VPC 設定

* **VPC 使用時の注意点**
  - Lambda Insights を使用する場合、VPC に NAT Gateway または VPC Endpoint（CloudWatch Logs / CloudWatch / ECR）が必要
  - VPC 自体の管理は外部で実施（このモジュールでは Subnet ID / Security Group ID を受け取るのみ）

* **Security Group の自動作成**
  - `use_vpc = true` かつ `security_group_ids = []`（空リスト）の場合、デフォルトの Security Group を自動作成
  - デフォルト Security Group は全てのアウトバウンド通信を許可（`0.0.0.0/0`）
  - インバウンドルールは設定されない（Lambda は通常インバウンド通信を受けない）

---

## 🏷 管理範囲

### ✔ 管理する（このモジュールで作成される）

#### ECR
* **ECR リポジトリ**
  - イメージスキャンを有効化（`scan_on_push = true`）
  - イメージタグは MUTABLE

#### Lambda 関数
* **Lambda 関数（コンテナイメージ）**
  - パッケージタイプ: `Image`
  - アーキテクチャ: `x86_64`
  - JSON ログ形式（`log_format = "JSON"`）
  - ログレベル設定（Application / System: `INFO`）
* **Lambda 再帰実行制御設定**（`recursive_loop = "Terminate"`）
* **Lambda Event Invoke Config**
  - 最大イベント保持時間: 60秒（fail fast）
  - リトライ回数: 0 回
  - 成功 / 失敗の通知先設定（Destination）

#### IAM
* **Lambda 実行ロール**
* **基本ポリシーのアタッチ**
  - `AWSLambdaBasicExecutionRole`（CloudWatch Logs 書き込み）
  - `CloudWatchLambdaInsightsExecutionRolePolicy`（Lambda Insights）
  - `AWSLambdaVPCAccessExecutionRole`（VPC 使用時のみ）
  - `AWSXRayDaemonWriteAccess`（X-Ray 有効時のみ）
* **追加ポリシーのアタッチ**（`extra_policy_arns` で指定）
* **DLQ / Destination 用 IAM ポリシー**
  - SQS への `SendMessage` 権限
  - SNS への `Publish` 権限

#### CloudWatch
* **CloudWatch Log Group**（保持期間設定可能）
* **メトリックフィルタ**
  - `MemorySize`（割り当てメモリサイズ）
  - `MaxMemoryUsed`（最大メモリ使用量）
* **CloudWatch Alarms**
  - `Errors`（エラー・タイムアウト・OOM を含む）
  - `Throttles`（スロットリング）
  - `Duration`（実行時間）
  - `Invocations`（実行回数、`invocation_alarm_threshold` が `null` でない場合のみ作成）
  - `Memory Usage`（メモリ使用率、Metric Math で算出）
* **監視用 SNS Topic**（アラーム通知専用）

#### イベントソース
* **EventBridge スケジュール**
  - ルール作成（`rate()` / `cron()` 形式）
  - ターゲット設定（Lambda への紐付け）
  - Lambda Permission（EventBridge からの実行許可）
* **SNS トリガー**
  - SNS サブスクリプション（Lambda への配信）
  - Lambda Permission（SNS からの実行許可）
* **SQS トリガー**
  - イベントソースマッピング（バッチサイズ、ウィンドウ設定）
  - Lambda 実行ロールへの SQS アクセス権限付与

### ✖ 管理しない（外部で管理）

| 種類 | 担当 | 理由 |
|-----|------|------|
| SNS トピック本体 | `chatbot` / 各種サービスモジュール | 汎用性が高く、Lambda 専用ではないため |
| SQS キュー本体 | 各サービスモジュール | 複数の Lambda/APIGW から利用されうるため |
| API Gateway リソース | `apigateway` モジュール | Lambda のリソースポリシーを APIGW 側で保持し循環依存を回避 |
| Step Functions 定義 | `stepfunctions` モジュール | Lambda Invoke Permission を Step Functions 側に置く |
| VPC（Subnets / SG） | ネットワークモジュール | Lambda 以外のリソースとも共有されるため |
| DLQ / Destination 用 SQS/SNS 本体 | 外部管理 | 汎用的なキューで、Lambda 専用ではない |

---

## 📋 変数（Variables）

### 必須変数

| 変数名 | 型 | 説明 |
|--------|---|------|
| `function_name` | `string` | Lambda 関数名（AWS アカウント内でユニークにする必要がある） |
| `ecr_repository_name` | `string` | ECR リポジトリ名 |

### Lambda 基本設定

| 変数名 | 型 | デフォルト | 説明 |
|--------|---|-----------|------|
| `description` | `string` | `""` | Lambda 関数の説明 |
| `image_tag` | `string` | `"latest"` | 使用する ECR イメージタグ |
| `memory_size` | `number` | `512` | メモリサイズ（MB） |
| `timeout` | `number` | `10` | タイムアウト（秒） |
| `storage_size` | `number` | `512` | エフェメラルストレージサイズ（MB） |
| `environment_variables` | `map(string)` | `{}` | 環境変数 |
| `reserved_concurrent_executions` | `number` | `-1` | Lambda の最大同時実行数（-1 は無制限） |
| `extra_policy_arns` | `list(string)` | `[]` | Lambda 実行ロールに追加で付与するマネージドポリシー ARN リスト |

### VPC 設定

| 変数名 | 型 | デフォルト | 説明 |
|--------|---|-----------|------|
| `use_vpc` | `bool` | `false` | Lambda を VPC 内で実行するかどうか |
| `subnet_ids` | `list(string)` | `[]` | VPC Subnet IDs（`use_vpc = true` の場合必須） |
| `security_group_ids` | `list(string)` | `[]` | VPC Lambda 用 security group IDs（`use_vpc = true` のとき必要。空リストの場合はデフォルトのSGを自動作成） |

### DLQ / Destination 設定

| 変数名 | 型 | デフォルト | 説明 |
|--------|---|-----------|------|
| `dlq_arn` | `string` | `""` | Dead Letter Queue の SQS or SNS ARN |
| `destination_on_failure_arn` | `string` | `""` | Event Invoke Config の失敗時送信先 SQS or SNS ARN |
| `destination_on_success_arn` | `string` | `""` | Event Invoke Config の成功時送信先 SQS or SNS ARN |

### イベントソース設定

| 変数名 | 型 | デフォルト | 説明 |
|--------|---|-----------|------|
| `eventbridge_schedules` | `list(object)` | `[]` | EventBridge スケジュール定義のリスト |
| `sns_event_sources` | `list(object)` | `[]` | SNS イベントソース設定のリスト |
| `sqs_event_sources` | `list(object)` | `[]` | SQS イベントソース設定のリスト |

#### `eventbridge_schedules` の構造

```hcl
eventbridge_schedules = [
  {
    name                = string  # ルール名
    schedule_expression = string  # rate(...) or cron(...)
  }
]
```

#### `sns_event_sources` の構造

```hcl
sns_event_sources = [
  {
    name      = string  # 識別用名前
    topic_arn = string  # SNS Topic ARN
  }
]
```

#### `sqs_event_sources` の構造

```hcl
sqs_event_sources = [
  {
    name                           = string           # 識別用名前
    queue_arn                      = string           # SQS Queue ARN
    batch_size                     = optional(number) # デフォルト: 10
    maximum_batching_window_second = optional(number) # デフォルト: 0
  }
]
```

### ログ・監視設定

| 変数名 | 型 | デフォルト | 説明 |
|--------|---|-----------|------|
| `log_retention_in_days` | `number` | `731` | CloudWatch Logs の保持日数 |
| `error_alarm_threshold` | `number` | `1` | Error アラーム閾値（直近3分の1分あたりの合計回数） |
| `throttle_alarm_threshold` | `number` | `1` | Throttle アラーム閾値（直近3分の1分あたりの合計回数） |
| `duration_alarm_threshold` | `number` | `5000` | Duration アラーム閾値（直近15分の最大ミリ秒数） |
| `invocation_alarm_threshold` | `number` | `null` | Invocation アラーム閾値（直近15分の5分あたりの合計回数）。`null` の場合はアラームを作成しない |
| `memory_alarm_threshold` | `number` | `80` | メモリ使用率アラーム閾値（%、直近15分の最大値） |

### 機能フラグ

| 変数名 | 型 | デフォルト | 説明 |
|--------|---|-----------|------|
| `use_vpc` | `bool` | `false` | Lambda を VPC 内で動かすかどうか |
| `use_xray` | `bool` | `false` | X-Ray トレーシングを有効にするかどうか |

### メタ情報

| 変数名 | 型 | デフォルト | 説明 |
|--------|---|-----------|------|
| `project` | `string` | `""` | プロジェクト識別子 |
| `tags` | `map(any)` | `{}` | リソースに付与するタグ |

---

## 🧪 使用例（Usage Examples）

### 基本的な使用例

```hcl
module "lambda_example" {
  source = "./modules/lambda"

  project             = "sample"
  function_name       = "payment-worker"
  ecr_repository_name = "payment-worker"
  image_tag           = "v1.0.0"

  memory_size  = 1024
  timeout      = 30

  environment_variables = {
    STAGE = "prod"
  }

  # VPC（Security Group は指定、または空リストでデフォルトSG自動作成）
  use_vpc            = true
  subnet_ids         = ["subnet-xxxx"]
  security_group_ids = ["sg-xxxx"]  # 空リスト [] を指定するとデフォルトSGが自動作成される

  # EventBridge
  eventbridge_schedules = [
    {
      name                = "schedule-payment"
      schedule_expression = "rate(5 minutes)"
    }
  ]

  # SNS trigger
  sns_event_sources = [
    {
      name      = "payment-created"
      topic_arn = aws_sns_topic.payment_created.arn
    }
  ]

  # SQS trigger
  sqs_event_sources = [
    {
      name       = "payment-queue"
      queue_arn  = aws_sqs_queue.payment.arn
      batch_size = 10
    }
  ]
}
```

### DLQ / Destination を使用する例

```hcl
module "lambda_with_dlq" {
  source = "./modules/lambda"

  project             = "sample"
  function_name       = "order-processor"
  ecr_repository_name = "order-processor"
  image_tag           = "latest"

  memory_size = 512
  timeout     = 15

  # Dead Letter Queue（同期実行の失敗時）
  dlq_arn = aws_sqs_queue.lambda_dlq.arn

  # Destination（非同期実行の成功/失敗時）
  destination_on_failure_arn = aws_sqs_queue.lambda_failure.arn
  destination_on_success_arn = aws_sqs_queue.lambda_success.arn

  # アラーム閾値のカスタマイズ
  error_alarm_threshold      = 5
  memory_alarm_threshold     = 90
  duration_alarm_threshold   = 12000  # 12秒
  invocation_alarm_threshold = null   # null に設定すると Invocation アラームは作成されない
}
```

### X-Ray トレーシングを有効にする例

```hcl
module "lambda_with_xray" {
  source = "./modules/lambda"

  project             = "sample"
  function_name       = "data-processor"
  ecr_repository_name = "data-processor"

  # X-Ray を有効化
  use_xray = true

  # 追加の IAM ポリシー（DynamoDB へのアクセス）
  extra_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
  ]

  environment_variables = {
    TABLE_NAME = "orders"
  }
}
```

### 複数イベントソースを持つ例

```hcl
module "lambda_multi_source" {
  source = "./modules/lambda"

  project             = "sample"
  function_name       = "notification-handler"
  ecr_repository_name = "notification-handler"

  # 複数の SQS キューをイベントソースに設定
  sqs_event_sources = [
    {
      name       = "email-queue"
      queue_arn  = aws_sqs_queue.email.arn
      batch_size = 5
    },
    {
      name       = "sms-queue"
      queue_arn  = aws_sqs_queue.sms.arn
      batch_size = 10
    }
  ]

  # 複数の SNS トピックからも受信
  sns_event_sources = [
    {
      name      = "user-created"
      topic_arn = aws_sns_topic.user_created.arn
    },
    {
      name      = "order-completed"
      topic_arn = aws_sns_topic.order_completed.arn
    }
  ]

  # 定期実行も設定
  eventbridge_schedules = [
    {
      name                = "hourly-check"
      schedule_expression = "rate(1 hour)"
    }
  ]
}
```

### 同時実行数を制限する例

```hcl
module "lambda_with_concurrency_limit" {
  source = "./modules/lambda"

  project             = "sample"
  function_name       = "rate-limited-processor"
  ecr_repository_name = "rate-limited-processor"

  # 同時実行数を 10 に制限（コスト制御やレート制限対策）
  reserved_concurrent_executions = 10

  memory_size = 512
  timeout     = 30
}
```

---

## 📤 出力（Outputs）

### Lambda 基本情報

| Output 名 | 説明 |
|----------|------|
| `function_name` | Lambda 関数名 |
| `function_arn` | Lambda 関数 ARN（バージョン無し） |
| `function_qualified_arn` | 最新バージョンに紐づく Lambda の qualified ARN（バージョン付き） |
| `function_version` | 最新の Lambda バージョン番号 |

### IAM

| Output 名 | 説明 |
|----------|------|
| `role_arn` | Lambda 実行ロール ARN |

### CloudWatch

| Output 名 | 説明 |
|----------|------|
| `log_group_name` | CloudWatch Logs のロググループ名 |
| `alarm_sns_topic_arn` | Lambda アラーム通知用 SNS Topic ARN |
| `cloudwatch_alarm_arns` | CloudWatch Metric Alarm ARN のマップ（`error`, `throttle`, `memory`, `duration`, `invocation`。`invocation` は `invocation_alarm_threshold` が `null` でない場合のみ含まれる） |

### ECR

| Output 名 | 説明 |
|----------|------|
| `ecr_repository_url` | ECR リポジトリ URL（例: `123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/my-lambda`） |
| `ecr_repository_arn` | ECR リポジトリ ARN |

### イベントソース

| Output 名 | 説明 |
|----------|------|
| `eventbridge_rule_arns` | EventBridge スケジュールルール ARN のマップ（name => arn） |
| `sns_subscription_arns` | SNS → Lambda サブスクリプション ARN のマップ（name => arn） |
| `sqs_event_source_mapping_uuids` | SQS イベントソースマッピング UUID のマップ（name => uuid） |

### 使用例

```hcl
# Lambda ARN を他のリソースで参照
resource "aws_iam_policy" "example" {
  policy = jsonencode({
    Statement = [{
      Action   = "lambda:InvokeFunction"
      Resource = module.lambda_example.function_arn
    }]
  })
}

# アラーム通知を Chatbot に送信
module "chatbot" {
  source = "../chatbot"

  sns_topic_arns = [
    module.lambda_example.alarm_sns_topic_arn
  ]
}

# ECR リポジトリ URL を CI/CD で使用
output "ecr_url" {
  value = module.lambda_example.ecr_repository_url
}
```

---

## 🔗 関連モジュール

> ※ 各モジュールの詳細は、それぞれの README を参照してください。

### 実装済みモジュール

* **`chatbot`** ✅
  - CloudWatch アラームを Slack に通知
  - Lambda モジュールのアラーム SNS Topic と連携
  - 詳細: [modules/chatbot/README.md](../chatbot/README.md)

* **`apigateway`** ✅
  - HTTP API → Lambda のプロキシ統合
  - API Gateway のアラーム監視機能を提供
  - Lambda のリソースポリシー（Invoke Permission）は apigateway モジュール側で管理（循環依存回避のため）
  - 詳細: [modules/apigateway/README.md](../apigateway/README.md)

### 未実装モジュール

* **`stepfunctions`** 🔄
  - Lambda をオーケストレーションするステートマシン
  - Lambda Invoke Permission を Step Functions 側に配置予定

---
