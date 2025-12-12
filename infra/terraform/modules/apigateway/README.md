# API Gateway Module (Terraform)

このディレクトリは **AWS API Gateway (REST API) を Terraform で構築・管理するためのモジュール** です。

Lambda プロキシ統合、SQS 直接統合、カスタムドメイン、API キー、CloudWatch 監視など、
API Gateway 運用に必要なリソースを包括的に作成します。

他のモジュール（例：Lambda、Chatbot）と連携して
**サーバーレス API を完全 IaC 化するための基盤** となります。

---

## 📌 目的

API Gateway の構築・管理をリポジトリ横断で統一し、
従来の手動構築や設定ファイルのコピペ運用にあった課題を解決するために設計された Terraform モジュールです。

### このモジュールが解決する主なポイント

* API Gateway の構成・監視・統合設定をすべて Terraform 化し、コピペ文化・属人化を解消
* Lambda プロキシ統合と SQS 直接統合の両方に対応し、柔軟なアーキテクチャを実現
* カスタムドメインの設定を自動化し、Route53 レコードまで一括管理
* API キーと使用量プラン（Usage Plan）による API アクセス制御を標準化
* CloudWatch アラームによる監視を自動構築し、Chatbot との連携で Slack 通知を実現

---

## 📁 構成

```
modules/
  apigateway/
    apigateway.tf          # REST API 本体、リソース階層の自動生成、リソースポリシー
    stage.tf               # デプロイメント、ステージ、API キー、使用量プラン
    domain.tf              # カスタムドメイン、Route53 レコード
    cloudwatch.tf          # ログ、アラーム、SNS Topic
    iam.tf                 # CloudWatch Logs 書き込み用 IAM Role、リソースポリシー
    data.tf                # AWS アカウント情報、リージョン情報
    variables.tf           # 入力変数
    outputs.tf             # 出力値
    README.md              # このファイル
    methods/               # 統合タイプ別のサブモジュール
      lambda_proxy/        # Lambda プロキシ統合
        main.tf
        variables.tf
        outputs.tf
        data.tf
      sqs/                 # SQS 直接統合
        main.tf
        iam.tf
        variables.tf
        outputs.tf
        data.tf
```

### ファイル概要

| ファイル | 内容 |
|---------|------|
| `apigateway.tf` | REST API 本体、リソース階層の自動生成（最大4階層まで対応）、リソースポリシー |
| `stage.tf` | デプロイメント、ステージ設定、API キー、使用量プラン |
| `domain.tf` | カスタムドメイン、ACM 証明書、Route53 レコード（A/AAAA） |
| `cloudwatch.tf` | アクセスログ、実行ログ、CloudWatch アラーム、SNS Topic |
| `iam.tf` | API Gateway が CloudWatch Logs に書き込むための IAM Role、IP 制限用リソースポリシー |
| `data.tf` | AWS アカウント ID、リージョン情報の取得 |
| `variables.tf` | 入力変数 |
| `outputs.tf` | 出力値 |
| `methods/lambda_proxy/` | Lambda プロキシ統合のサブモジュール |
| `methods/sqs/` | SQS 直接統合のサブモジュール |

---

## 📝 設計ポリシー

### 基本方針

* API Gateway の「構築」「統合」「監視」「カスタムドメイン」までを一括提供し、**再利用性と統一性を最大化**
* Lambda プロキシ統合と SQS 直接統合の両方に対応し、**柔軟なアーキテクチャを実現**
* リソース階層を自動生成することで、**パス定義の手間を削減**
* Lambda のリソースポリシー（Invoke Permission）は **API Gateway モジュール側で管理**し、循環依存を回避
* Terraform 管理に一本化するための基盤となる

### モジュールの制約・設計方針

このモジュールは、シンプルさと管理性を重視した設計になっています。以下の制約を理解した上でご利用ください。

#### IP 制限

* **リソースポリシーによる IP 制限**
  - `allowed_source_ips` で許可する IP CIDR を指定（allowlist 運用）
  - `denied_source_ips` で拒否する IP CIDR を指定（denylist 運用）
  - 両方指定した場合、denylist が優先される
  - どちらも空リストの場合、IP 制限は適用されない

#### デプロイメント & ステージ

* **モジュール一つにつきデプロイメントとステージは一つのみ**
  - 複数ステージ（dev / staging / prod など）が必要な場合は、モジュールを複数作成
  - 同一 REST API で複数ステージを管理する場合は、モジュールの外で管理が必要

#### API キー & 使用量プラン

* **API キーと使用量プランは1セットのみ**
  - 複数の API キーや使用量プランは作成しない
  - メソッドごとに `api_key_required` で API キーの要否を制御
  - 複数クライアント向けに異なる API キーが必要な場合は、モジュールを分けるか外部で管理

#### スロットル設定

* **スロットルはメソッドレベルでは指定しない**
  - 使用量プラン全体でスロットル（`rate_limit` / `burst_limit`）を管理
  - メソッド別のスロットル制御が必要な場合は、Lambda 側で制御するか WAF を使用

#### リソース階層

* **リソース階層は最大4階層まで対応**
  - 例: `/v1/foo/bar/baz` まで対応
  - 5階層以上が必要な場合は、コード修正が必要
  - パス定義から階層を自動生成（例: `/v1/hello` → `/v1` と `/v1/hello` のリソースを自動生成）
  - プロキシパス（`{proxy+}`）にも対応

#### 認証・認可

* **Authorization は NONE 固定**
  - Cognito オーソライザーは未実装
  - Lambda オーソライザーは未実装
  - 認証が必要な場合は、API キーまたは Lambda 関数内で実装

#### エンドポイントタイプ

* **リージョナルエンドポイント固定（dualstack 対応）**
  - エッジ最適化エンドポイントは未対応
  - プライベート統合（VPC Link）は未対応

#### API タイプ

* **REST API（v1）のみ対応**
  - HTTP API（v2）は未対応
  - WebSocket API は未対応

#### カスタムドメイン

* **カスタムドメイン有効時はデフォルトエンドポイントを無効化**
  - `enable_custom_domain = true` の場合、`execute-api` エンドポイントは無効化される
  - テスト用にデフォルトエンドポイントも使いたい場合は、`enable_custom_domain = false` に設定
  - ACM 証明書による TLS 1.2 対応
  - Route53 レコード（A / AAAA）を自動作成

#### CloudWatch アラーム

* **アラームはステージ全体のメトリクスのみ**
  - 5XXError、4XXError、Latency、Count（リクエスト数）
  - メソッド別・リソース別のアラームは未実装
  - 詳細な監視が必要な場合は、外部で CloudWatch Alarms を追加作成
  - 3つの連続期間（15分）を評価し、1つのデータポイントでアラーム発火
  - SNS Topic への通知で Chatbot と連携

#### Lambda Invoke Permission の管理

* **Lambda のリソースポリシー（Invoke Permission）は API Gateway モジュール側で管理**
  - Lambda モジュールとの循環依存を回避
  - サブモジュール `methods/lambda_proxy` で自動作成

#### SQS 統合の IAM Role 管理

* **SQS 統合用の IAM Role はメソッド単位で作成**
  - `apigateway.amazonaws.com` からの AssumeRole を許可
  - SQS SendMessage 権限のみを付与
  - サブモジュール `methods/sqs` で自動作成

#### デプロイメントの自動化

* **メソッド定義変更時に自動で再デプロイ**
  - SHA1 ハッシュをトリガーに使用し、変更を検知

#### アクセスログの形式

* **アクセスログを JSON 形式で出力**
  - CloudWatch Logs Insights での分析を容易に
  - `requestId`, `requestTime`, `ip`, `httpMethod`, `resourcePath`, `status`, `responseLatency` などを記録

---

## 🏷 管理範囲

### ✔ 管理する（このモジュールで作成される）

#### REST API
* **REST API 本体**
  - リージョナルエンドポイント（dualstack 対応）
  - API キーソース: `HEADER`
  - カスタムドメイン有効時はデフォルトエンドポイントを無効化
* **リソースポリシー（IP 制限）**
  - `allowed_source_ips` による allowlist 運用（指定されたIP以外を拒否）
  - `denied_source_ips` による denylist 運用（指定されたIPを拒否）
  - 両方指定時は denylist が優先される
* **リソース階層の自動生成**
  - パスから最大4階層までのリソースを自動作成（例: `/v1/hello` → `/v1` と `/v1/hello`）
  - プロキシパス（`{proxy+}`）にも対応

#### Lambda プロキシ統合
* **Lambda プロキシ統合メソッド**（サブモジュール: `methods/lambda_proxy`）
  - メソッド定義（GET / POST / ANY など）
  - Lambda プロキシ統合（`AWS_PROXY`）
  - Lambda Invoke Permission（API Gateway からの実行許可）
  - タイムアウト: 29秒（上限値）

#### SQS 直接統合
* **SQS 直接統合メソッド**（サブモジュール: `methods/sqs`）
  - メソッド定義（GET / POST など）
  - SQS 統合（`AWS` タイプ、非プロキシ）
  - API Gateway → SQS への IAM Role（SendMessage 権限）
  - リクエスト/レスポンステンプレート、モデルの柔軟な設定
  - ステータスコード別のレスポンス定義

#### デプロイメント & ステージ
* **デプロイメント**
  - メソッド定義変更時の自動再デプロイ（SHA1 トリガー）
* **ステージ**
  - アクセスログ（JSON 形式）
  - X-Ray トレーシング（オプション）
  - メソッドレベルのメトリクス有効化
  - 実行ログレベル: INFO

#### API キー & 使用量プラン
* **API キー**（オプション）
* **使用量プラン**
  - スロットル設定（rate_limit / burst_limit）
  - クオータ設定（limit / period）
  - ステージとの紐付け

#### カスタムドメイン
* **カスタムドメイン名**（オプション）
  - ACM 証明書による TLS 1.2
  - リージョナルエンドポイント（dualstack）
* **ベースパスマッピング**
* **Route53 レコード**（A / AAAA）
  - 既存 Hosted Zone へのエイリアスレコード作成

#### CloudWatch 監視
* **CloudWatch Log Group**
  - アクセスログ（保持期間設定可能）
  - 実行ログ（保持期間設定可能）
* **CloudWatch Alarms**
  - `5XXError`（サーバーエラー）
  - `4XXError`（クライアントエラー）
  - `Latency`（レイテンシ）
  - `Count`（リクエスト数）
* **監視用 SNS Topic**（アラーム通知専用）

#### IAM
* **API Gateway → CloudWatch Logs 書き込み用 IAM Role**
  - `apigateway.amazonaws.com` からの AssumeRole を許可
  - CloudWatch Logs への書き込み権限
* **API Gateway → SQS 送信用 IAM Role**（SQS 統合時のみ）
  - メソッド単位で IAM Role を作成
  - SQS SendMessage 権限

### ✖ 管理しない（外部で管理）

#### 外部モジュールが担当

| 種類 | 担当モジュール | 理由 |
|-----|--------------|------|
| Lambda 関数本体 | `lambda` モジュール | Lambda の構築・監視は Lambda モジュールで一括管理 |
| SQS キュー本体 | 各サービスモジュール | 複数の API / Lambda から利用されうるため |
| SNS トピック本体（イベント用） | 各サービスモジュール | 汎用性が高く、API Gateway 専用ではないため |
| ACM 証明書 | 外部管理 | 複数のサービスで共有されるため |
| Route53 Hosted Zone | 外部管理 | ドメイン全体の管理は外部で実施 |
| WAF | 外部管理 | API Gateway 以外のリソースとも連携するため |

#### 未実装機能

| 項目 | 理由 |
|-----|------|
| Cognito オーソライザー | 未実装（必要に応じて追加予定） |
| Lambda オーソライザー | 未実装（必要に応じて追加予定） |
| VPC Link | 未実装（プライベート統合が必要な場合に追加予定） |
| HTTP API（v2） | REST API（v1）のみ対応 |

---

## 📋 変数（Variables）

### 必須変数

| 変数名 | 型 | 説明 |
|--------|---|------|
| `name` | `string` | API Gateway 名（プロジェクト名含む想定） |

### API Gateway 基本設定

| 変数名 | 型 | デフォルト | 説明 |
|--------|---|-----------|------|
| `stage_name` | `string` | `"prod"` | ステージ名（デプロイ時に使用） |

### IP 制限設定

| 変数名 | 型 | デフォルト | 説明 |
|--------|---|-----------|------|
| `allowed_source_ips` | `list(string)` | `[]` | 許可する Source IP CIDR（指定すると allowlist 運用: それ以外は拒否） |
| `denied_source_ips` | `list(string)` | `[]` | 拒否する Source IP CIDR（deny は allow より優先） |

### Lambda プロキシ統合設定

| 変数名 | 型 | デフォルト | 説明 |
|--------|---|-----------|------|
| `lambda_proxy_methods` | `list(object)` | `[]` | Lambda プロキシ統合メソッドのリスト |

#### `lambda_proxy_methods` の構造

```hcl
lambda_proxy_methods = [
  {
    path             = string           # "/v1/hello" など
    http_method      = string           # "GET", "POST", "ANY" など
    lambda_arn       = string           # Lambda 関数 ARN
    api_key_required = optional(bool)   # デフォルト: false
  }
]
```

### SQS 統合設定

| 変数名 | 型 | デフォルト | 説明 |
|--------|---|-----------|------|
| `sqs_methods` | `list(object)` | `[]` | SQS 統合メソッドのリスト |

#### `sqs_methods` の構造

```hcl
sqs_methods = [
  {
    path                       = string                    # "/v1/enqueue" など
    http_method                = string                    # "POST" など
    queue_arn                  = string                    # SQS Queue ARN
    queue_name                 = string                    # SQS Queue Name
    api_key_required           = optional(bool)            # デフォルト: false
    request_parameters         = optional(map(string))     # メソッドのリクエストパラメータ
    request_models             = optional(map(string))     # メソッドのリクエストモデル
    integration_http_method    = optional(string)          # デフォルト: "POST"
    request_parameters_mapping = optional(map(string))     # 統合のリクエストパラメータマッピング
    request_templates_mapping  = optional(map(string))     # 統合のリクエストテンプレート
    responses                  = list(object)              # レスポンス定義（詳細は後述）
    response_models            = optional(map(object))     # レスポンスモデル定義
  }
]
```

#### `sqs_methods` の `responses` 構造

```hcl
responses = [
  {
    status_code                 = string                    # "200", "400" など
    selection_pattern           = optional(string)          # "" ならデフォルト、正規表現で指定
    response_models             = optional(map(string))     # content-type => モデル名
    response_parameters_mapping = optional(map(string))     # レスポンスパラメータマッピング
    response_templates_mapping  = optional(map(string))     # content-type => テンプレート文字列
  }
]
```

### API キー & 使用量プラン

| 変数名 | 型 | デフォルト | 説明 |
|--------|---|-----------|------|
| `enable_api_key` | `bool` | `false` | API キーを作成するかどうか |
| `usage_plan_throttle` | `object` | `{}` | スロットル設定（rate_limit / burst_limit） |
| `usage_plan_quota` | `object` | `{}` | クオータ設定（limit / period） |

### カスタムドメイン設定

| 変数名 | 型 | デフォルト | 説明 |
|--------|---|-----------|------|
| `enable_custom_domain` | `bool` | `true` | カスタムドメインを有効にするかどうか |
| `domain_name` | `string` | `""` | カスタムドメイン名（例: `api.example.com`） |
| `acm_certificate_arn` | `string` | `""` | ACM 証明書 ARN |
| `zone_id` | `string` | `""` | Route53 Hosted Zone ID |

### ログ・監視設定

| 変数名 | 型 | デフォルト | 説明 |
|--------|---|-----------|------|
| `access_log_retention_in_days` | `number` | `731` | アクセスログの保持日数 |
| `execution_log_retention_in_days` | `number` | `731` | 実行ログの保持日数 |
| `stage_alarm_config` | `object` | `{}` | ステージ全体のアラーム閾値設定 |
| `use_xray` | `bool` | `false` | X-Ray トレーシングを有効にするかどうか |
| `manage_apigw_account_logging_role` | `bool` | `false` | API Gateway アカウントレベルのロギング Role を管理するかどうか |

#### `stage_alarm_config` の構造

```hcl
stage_alarm_config = {
  five_xx_error_threshold = optional(number)  # 5XXエラー閾値（5分間の合計）
  four_xx_error_threshold = optional(number)  # 4XXエラー閾値（5分間の合計）
  latency_threshold_ms    = optional(number)  # レイテンシ閾値（ミリ秒、最大値）
  count_threshold         = optional(number)  # リクエスト数閾値（5分間の合計）
}
```

### メタ情報

| 変数名 | 型 | デフォルト | 説明 |
|--------|---|-----------|------|
| `project` | `string` | `""` | プロジェクト識別子 |
| `tags` | `map(any)` | `{}` | リソースに付与するタグ |

---

## 🧪 使用例（Usage Examples）

### 基本的な使用例（Lambda プロキシ統合のみ）

```hcl
module "apigateway_simple" {
  source = "./modules/apigateway"

  project = "sample"
  name    = "sample-api"

  lambda_proxy_methods = [
    {
      path        = "/{proxy+}"
      http_method = "ANY"
      lambda_arn  = module.lambda_app.function_arn
    }
  ]

  # カスタムドメインは無効化
  enable_custom_domain = false
}
```

### Lambda プロキシ統合 + カスタムドメイン

```hcl
module "apigateway_with_domain" {
  source = "./modules/apigateway"

  project = "sample"
  name    = "sample-api"

  # カスタムドメイン設定
  enable_custom_domain = true
  domain_name          = "api.example.com"
  acm_certificate_arn  = "arn:aws:acm:ap-northeast-1:123456789012:certificate/xxxxx"
  zone_id              = "Z1234567890ABC"

  # Lambda プロキシ統合
  lambda_proxy_methods = [
    {
      path        = "/v1/hello"
      http_method = "GET"
      lambda_arn  = module.lambda_hello.function_arn
    },
    {
      path        = "/v1/{proxy+}"
      http_method = "ANY"
      lambda_arn  = module.lambda_app.function_arn
    }
  ]
}
```

### IP 制限の使用例（Allowlist 運用）

```hcl
module "apigateway_with_ip_restriction" {
  source = "./modules/apigateway"

  project = "sample"
  name    = "sample-api-restricted"

  # IP 制限（allowlist）- 指定された IP からのみアクセス可能
  allowed_source_ips = [
    "203.0.113.0/24",  # オフィスネットワーク
    "198.51.100.5/32"  # 特定のサーバー
  ]

  # Lambda プロキシ統合
  lambda_proxy_methods = [
    {
      path        = "/{proxy+}"
      http_method = "ANY"
      lambda_arn  = module.lambda_app.function_arn
    }
  ]
}
```

### IP 制限の使用例（Denylist 運用）

```hcl
module "apigateway_with_ip_denylist" {
  source = "./modules/apigateway"

  project = "sample"
  name    = "sample-api-public"

  # IP 制限（denylist）- 指定された IP からのアクセスを拒否
  denied_source_ips = [
    "192.0.2.100/32",  # 悪意のある IP
    "192.0.2.0/24"     # ブロックしたいネットワーク
  ]

  # Lambda プロキシ統合
  lambda_proxy_methods = [
    {
      path        = "/{proxy+}"
      http_method = "ANY"
      lambda_arn  = module.lambda_app.function_arn
    }
  ]
}
```

### IP 制限の使用例（Allowlist + Denylist 併用）

```hcl
module "apigateway_with_mixed_ip_policy" {
  source = "./modules/apigateway"

  project = "sample"
  name    = "sample-api-mixed"

  # Allowlist（基本的に社内ネットワークのみ許可）
  allowed_source_ips = [
    "203.0.113.0/24"  # オフィスネットワーク
  ]

  # Denylist（社内ネットワーク内でも特定IPは拒否）
  # Deny が優先されるため、このIPは社内ネットワークでもアクセス不可
  denied_source_ips = [
    "203.0.113.99/32"  # 社内の問題のあるIP
  ]

  # Lambda プロキシ統合
  lambda_proxy_methods = [
    {
      path        = "/{proxy+}"
      http_method = "ANY"
      lambda_arn  = module.lambda_app.function_arn
    }
  ]
}
```

### API キー + 使用量プラン

```hcl
module "apigateway_with_api_key" {
  source = "./modules/apigateway"

  project = "sample"
  name    = "sample-api"

  # API キー有効化
  enable_api_key = true

  # スロットル設定
  usage_plan_throttle = {
    rate_limit  = 100   # 1秒あたり100リクエスト
    burst_limit = 50    # バースト50リクエスト
  }

  # クオータ設定
  usage_plan_quota = {
    limit  = 100000   # 月間10万リクエストまで
    period = "MONTH"
  }

  # Lambda プロキシ統合（API キー必須）
  lambda_proxy_methods = [
    {
      path             = "/v1/{proxy+}"
      http_method      = "ANY"
      lambda_arn       = module.lambda_app.function_arn
      api_key_required = true
    }
  ]
}
```

### SQS 直接統合（POST + SendMessage）

```hcl
module "apigateway_with_sqs" {
  source = "./modules/apigateway"

  project = "sample"
  name    = "sample-api"

  # SQS 統合メソッド
  sqs_methods = [
    {
      path       = "/v1/enqueue"
      http_method = "POST"
      queue_arn  = aws_sqs_queue.main.arn
      queue_name = aws_sqs_queue.main.name

      # リクエストテンプレート（JSON を SQS SendMessage にマッピング）
      request_parameters_mapping = {
        "integration.request.header.Content-Type" = "'application/x-www-form-urlencoded'"
      }

      request_templates_mapping = {
        "application/json" = "Action=SendMessage&MessageBody=$util.urlEncode($input.body)"
      }

      # レスポンス定義
      responses = [
        {
          status_code       = "200"
          selection_pattern = "" # デフォルトレスポンス

          response_parameters_mapping = {
            "method.response.header.Content-Type" = "'application/json'"
          }

          response_templates_mapping = {
            "application/json" = "{ \"message\": \"Message enqueued successfully.\" }"
          }

          response_models = {}
        }
      ]

      response_models = {}
    }
  ]
}
```

### SQS 直接統合（GET + リダイレクト）

```hcl
module "apigateway_with_sqs_redirect" {
  source = "./modules/apigateway"

  project = "sample"
  name    = "sample-api"

  sqs_methods = [
    {
      path             = "/v2/enqueue"
      http_method      = "GET"
      queue_arn        = aws_sqs_queue.secondary.arn
      queue_name       = aws_sqs_queue.secondary.name
      api_key_required = false

      # リクエストパラメータ（GET クエリで SQS SendMessage）
      integration_http_method = "GET"
      request_parameters_mapping = {
        "integration.request.querystring.Action"      = "'SendMessage'"
        "integration.request.querystring.MessageBody" = "'Hello from API Gateway'"
        "integration.request.querystring.Version"     = "'2012-11-05'"
      }

      request_templates_mapping = {}

      # レスポンス（302 リダイレクト）
      responses = [
        {
          status_code       = "302"
          selection_pattern = ""

          response_parameters_mapping = {
            "method.response.header.Location" = "'https://example.com'"
          }

          response_templates_mapping = {}
          response_models            = {}
        }
      ]

      response_models = {}
    }
  ]
}
```

### Lambda & SQS 統合の併用 + 監視設定

```hcl
module "apigateway_full" {
  source = "./modules/apigateway"

  project    = "sample"
  name       = "sample-api-prod"
  stage_name = "production"

  # カスタムドメイン
  enable_custom_domain = true
  domain_name          = "api.example.com"
  acm_certificate_arn  = var.acm_arn
  zone_id              = var.zone_id

  # IP 制限（オプション）
  allowed_source_ips = ["203.0.113.0/24"]  # 社内ネットワークのみ許可
  denied_source_ips  = []                  # 特定の拒否IPがあれば設定

  # API キー
  enable_api_key = true
  usage_plan_throttle = {
    rate_limit  = 50
    burst_limit = 20
  }

  # Lambda プロキシ統合
  lambda_proxy_methods = [
    {
      path        = "/v1/hello"
      http_method = "GET"
      lambda_arn  = module.lambda_hello.function_arn
    },
    {
      path             = "/v1/{proxy+}"
      http_method      = "ANY"
      lambda_arn       = module.lambda_app.function_arn
      api_key_required = true
    }
  ]

  # SQS 統合
  sqs_methods = [
    {
      path             = "/v1/enqueue"
      http_method      = "POST"
      queue_arn        = aws_sqs_queue.main.arn
      queue_name       = aws_sqs_queue.main.name
      api_key_required = true

      integration_http_method = "POST"
      request_parameters_mapping = {
        "integration.request.header.Content-Type" = "'application/x-www-form-urlencoded'"
      }
      request_templates_mapping = {
        "application/json" = "Action=SendMessage&MessageBody=$util.urlEncode($input.body)"
      }

      responses = [
        {
          status_code                 = "200"
          selection_pattern           = ""
          response_parameters_mapping = {
            "method.response.header.Content-Type" = "'application/json'"
          }
          response_templates_mapping = {
            "application/json" = "{ \"message\": \"Enqueued\" }"
          }
          response_models = {}
        }
      ]

      response_models = {}
    }
  ]

  # 監視設定
  access_log_retention_in_days    = 30
  execution_log_retention_in_days = 30
  use_xray                        = true

  stage_alarm_config = {
    five_xx_error_threshold = 1     # 5XXエラーが1回以上で通知
    latency_threshold_ms    = 1000  # レイテンシ1秒以上で通知
    count_threshold         = 1000  # リクエスト数1000以上で通知
  }

  tags = {
    Environment = "production"
  }
}
```

---

## 📤 出力（Outputs）

### REST API 基本情報

| Output 名 | 説明 |
|----------|------|
| `rest_api_id` | REST API ID |
| `root_resource_id` | ルートリソース ID |
| `execution_arn` | REST API の実行 ARN |
| `stage_name` | ステージ名 |

### API キー

| Output 名 | 説明 |
|----------|------|
| `api_key_value` | API キーの値（sensitive、`enable_api_key = true` 時のみ） |

### リソース階層

| Output 名 | 説明 |
|----------|------|
| `level1_resource_ids` | レベル1リソースのマップ（例: `/v1`） |
| `level2_resource_ids` | レベル2リソースのマップ（例: `/v1/hello`） |
| `level3_resource_ids` | レベル3リソースのマップ（例: `/v1/foo/bar`） |
| `level4_resource_ids` | レベル4リソースのマップ（例: `/v1/foo/bar/baz`） |
| `resource_ids` | 全リソースのマップ（`/` 含む） |

### CloudWatch

| Output 名 | 説明 |
|----------|------|
| `alarm_sns_topic_arn` | API Gateway アラーム通知用 SNS Topic ARN |

### 使用例

```hcl
# API キーを出力
output "api_key" {
  value     = module.apigateway.api_key_value
  sensitive = true
}

# アラーム通知を Chatbot に送信
module "chatbot" {
  source = "../chatbot"

  sns_topic_arns = [
    module.apigateway.alarm_sns_topic_arn
  ]
}

# REST API ID を他のリソースで参照
output "rest_api_id" {
  value = module.apigateway.rest_api_id
}
```

---

## 🔗 関連モジュール

> ※ 各モジュールの詳細は、それぞれの README を参照してください。

### 実装済みモジュール

* **`lambda`** ✅
  - Lambda 関数の構築・監視・イベント設定
  - API Gateway から呼び出される Lambda 関数を提供
  - Lambda Invoke Permission は API Gateway モジュール側で管理
  - 詳細: [modules/lambda/README.md](../lambda/README.md)

* **`chatbot`** ✅
  - CloudWatch アラームを Slack に通知
  - API Gateway モジュールのアラーム SNS Topic と連携
  - 詳細: [modules/chatbot/README.md](../chatbot/README.md)

### 未実装モジュール

* **`waf`** 🔄
  - WAF による API Gateway の保護
  - レート制限、IP 制限、SQL インジェクション対策など

---

## 📚 参考リンク

- [AWS API Gateway 公式ドキュメント](https://docs.aws.amazon.com/apigateway/latest/developerguide/)
- [Terraform AWS API Gateway Resources](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_rest_api)
- [API Gateway と Lambda の統合](https://docs.aws.amazon.com/apigateway/latest/developerguide/set-up-lambda-integrations.html)
- [API Gateway と SQS の統合](https://docs.aws.amazon.com/apigateway/latest/developerguide/integrating-api-with-aws-services-sqs.html)

---
