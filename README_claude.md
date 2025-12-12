# serverless-terraform

AWS サーバーレス構成を Terraform Modules で完全 IaC 化するプロジェクト

---

## 目次

- [1. プロジェクト概要](#1-プロジェクト概要)
- [2. プロジェクト構成](#2-プロジェクト構成)
- [3. システムアーキテクチャ](#3-システムアーキテクチャ)
- [4. Terraform モジュール詳細](#4-terraform-モジュール詳細)
- [5. 開発環境（Docker Compose）](#5-開発環境docker-compose)
- [6. セットアップ手順](#6-セットアップ手順)
- [7. Lambda コンテナイメージのビルド＆デプロイ](#7-lambda-コンテナイメージのビルドデプロイ)
- [8. 運用ガイド](#8-運用ガイド)
- [9. 設計思想と制約](#9-設計思想と制約)
- [10. 今後の予定](#10-今後の予定)

---

## 1. プロジェクト概要

### 1.1 目的

このリポジトリは、
**AWS Lambda / API Gateway / Chatbot / SNS / SQS などのサーバーレス構成を Terraform Modules で完全 IaC 化するためのプロジェクト** です。

Serverless Framework を段階的に廃止し、
**ECR ベースの Lambda 運用 × Terraform 管理 × CI/CD 自動化**
への統合移行により、**再利用性・拡張性・信頼性の高い運用基盤**の構築を目的としています。

### 1.2 背景と課題

従来、Serverless Framework を利用していましたが、以下の問題がありました：

| 課題 | 詳細 |
|------|------|
| **テンプレのコピペ運用** | プロジェクトごとにテンプレートをコピペしており、設定の不整合が発生 |
| **属人化** | インフラ有識者しか管理できず、ナレッジが共有されない |
| **CI/CD 不足** | 手元のホストPCや手動デプロイが多く、ミスしやすい |
| **Serverless Framework の限界** | v3 は Python 3.11 までしかサポートせず EOL、v4 は有料ライセンス |
| **完結しない構成** | API Gateway + WAF、Chatbot などは Terraform 管理となり、Serverless だけでは完結しない |
| **起動速度** | Lambda レイヤーより**コンテナイメージの方が起動時間が短い** |

### 1.3 解決策

このプロジェクトでは以下のアプローチで課題を解決します：

| 解決策 | 内容 |
|--------|------|
| **ECR ベースの Lambda** | Lambda はすべて Docker コンテナイメージで管理 |
| **Terraform Modules 化** | Lambda / Chatbot / API Gateway をモジュール化 |
| **完全 IaC 化** | インフラ構成をすべて Terraform で管理し、属人化を排除 |
| **CI/CD 統合** | GitHub Actions で自動デプロイを実現（Docker ビルド → ECR プッシュ → Lambda 更新） |

---

## 2. プロジェクト構成

### 2.1 ディレクトリ構造

```
.
├── .github/
│   └── workflows/
│       └── deployment.yml          # GitHub Actions（CI/CD、Lambda 自動デプロイ）
├── .gitignore                      # Git 管理外ファイル設定
├── docker-compose.yml              # ローカル開発環境
├── README.md                       # 既存ドキュメント（若干古い）
├── README2.md                      # Notion からのメモ
├── README_claude.md                # このファイル（包括的ドキュメント）
│
├── infra/
│   ├── docker/
│   │   ├── development/            # ローカル開発用 Dockerfile 群
│   │   │   ├── lambda_first/Dockerfile
│   │   │   ├── lambda_second/Dockerfile
│   │   │   ├── python/Dockerfile
│   │   │   ├── sls-deploy/Dockerfile
│   │   │   └── claude/Dockerfile   # Claude Code 実行環境
│   │   └── production/             # 本番環境用 Dockerfile 群
│   │       ├── lambda_first/Dockerfile
│   │       └── lambda_second/Dockerfile
│   │
│   └── terraform/
│       ├── modules/                # 再利用可能な Terraform モジュール
│       │   ├── lambda/             # Lambda + ECR + CloudWatch + IAM + イベント設定
│       │   │   ├── cloudwatch.tf
│       │   │   ├── ecr.tf
│       │   │   ├── event_schedule.tf
│       │   │   ├── event_sns.tf
│       │   │   ├── event_sqs.tf
│       │   │   ├── iam.tf
│       │   │   ├── iam_destination.tf
│       │   │   ├── lambda.tf
│       │   │   ├── security_group.tf  # VPC 用デフォルト SG（条件付き作成）
│       │   │   ├── outputs.tf
│       │   │   ├── variables.tf
│       │   │   └── README.md
│       │   │
│       │   ├── apigateway/         # API Gateway (REST API v1) + Lambda/SQS 統合 + IP 制限
│       │   │   ├── apigateway.tf
│       │   │   ├── cloudwatch.tf
│       │   │   ├── data.tf           # AWS アカウント情報、リージョン情報
│       │   │   ├── domain.tf
│       │   │   ├── iam.tf            # IAM Role、リソースポリシー
│       │   │   ├── stage.tf
│       │   │   ├── outputs.tf
│       │   │   ├── variables.tf
│       │   │   ├── README.md
│       │   │   └── methods/
│       │   │       ├── lambda_proxy/  # Lambda プロキシ統合サブモジュール
│       │   │       └── sqs/           # SQS 直接統合サブモジュール
│       │   │
│       │   └── chatbot/            # AWS Chatbot（Slack 通知）
│       │       ├── chatbot.tf
│       │       ├── iam.tf
│       │       ├── outputs.tf
│       │       ├── variables.tf
│       │       └── README.md
│       │
│       └── production/             # 本番環境固有の設定
│           ├── environments.tf     # Lambda 環境変数の定義
│           ├── flags.tf            # 機能フラグ（VPC、X-Ray など）
│           ├── import.tf           # Terraform import 用（既存リソース）
│           ├── locals.tf           # ローカル変数（プロジェクト名、Lambda/API Gateway 設定など）
│           ├── main.tf             # プロバイダー設定
│           ├── modules.tf          # モジュール呼び出し
│           ├── terraform.tf        # Terraform バージョン・バックエンド設定
│           ├── variables.tf        # 入力変数（Slack、VPC、SQS、SNS、ACM、Route53 など）
│           ├── terraform.tfstate   # 状態ファイル（本来は S3 管理推奨）
│           └── terraform.tfstate.backup
│
└── serverless/                     # Lambda 関数コード
    ├── lambda_first.py
    └── lambda_second.py
```

### 2.2 各ディレクトリの役割

| ディレクトリ | 役割 |
|-------------|------|
| **`.github/workflows/`** | GitHub Actions の CI/CD 定義（main ブランチへの push で Lambda 自動デプロイ） |
| **`infra/docker/development/`** | ローカル開発用の Dockerfile（Lambda のテスト実行環境など） |
| **`infra/docker/production/`** | 本番環境用の Lambda コンテナイメージ Dockerfile |
| **`infra/terraform/modules/`** | 再利用可能な Terraform モジュール（Lambda、API Gateway、Chatbot） |
| **`infra/terraform/production/`** | 本番環境固有の Terraform 設定（ここで `terraform apply` を実行） |
| **`serverless/`** | Lambda 関数の Python コード |

---

## 3. システムアーキテクチャ

### 3.1 全体構成図

```
┌────────────────────────────────────────────────────────────────────┐
│                          AWS Cloud                                  │
│                                                                      │
│  ┌──────────────┐                                                   │
│  │ EventBridge  │ (スケジュール実行)                                    │
│  │  Schedule    │──────┐                                            │
│  └──────────────┘      │                                            │
│                        ▼                                            │
│  ┌──────────────┐   ┌──────────────┐   ┌─────────────┐             │
│  │     SNS      │──>│    Lambda    │   │     ECR     │             │
│  │   Topic      │   │   Function   │<──│ Repository  │             │
│  └──────────────┘   └──────────────┘   └─────────────┘             │
│                        │                      ▲                     │
│  ┌──────────────┐     │                      │                     │
│  │     SQS      │─────┘                      │                     │
│  │    Queue     │                            │ (Docker Push)       │
│  └──────────────┘                            │                     │
│                                               │                     │
│  ┌───────────────┐   ┌──────────────┐        │                     │
│  │  API Gateway  │──>│    Lambda    │        │                     │
│  │  (REST API)   │   │   Function   │        │                     │
│  └───────────────┘   └──────────────┘        │                     │
│         │                                     │                     │
│         │ (SQS 直接統合)                        │                     │
│         ▼                                     │                     │
│  ┌──────────────┐                            │                     │
│  │     SQS      │                            │                     │
│  │    Queue     │                            │                     │
│  └──────────────┘                            │                     │
│                                               │                     │
│  ┌───────────────┐   ┌─────────────┐         │                     │
│  │  CloudWatch   │──>│  SNS Alarm  │         │                     │
│  │    Alarms     │   │    Topic    │         │                     │
│  └───────────────┘   └─────────────┘         │                     │
│                          │                    │                     │
│  ┌───────────────┐      │                    │                     │
│  │ AWS Chatbot   │<─────┘                    │                     │
│  │   (Slack)     │                           │                     │
│  └───────────────┘                           │                     │
│         │                                     │                     │
└─────────│─────────────────────────────────────│─────────────────────┘
          │                                     │
          ▼                                     │
    ┌─────────┐                          ┌──────────────┐
    │  Slack  │                          │ GitHub       │
    │ Channel │                          │ Actions      │
    └─────────┘                          │ (CI/CD)      │
                                         └──────────────┘
```

### 3.2 コンポーネント説明

| コンポーネント | 説明 | 管理範囲 |
|--------------|------|---------|
| **ECR Repository** | Lambda コンテナイメージの保管場所 | Lambda モジュール |
| **Lambda Function** | Lambda 本体（コンテナイメージ実行） | Lambda モジュール |
| **API Gateway** | REST API (v1)、Lambda プロキシ統合・SQS 直接統合、IP 制限 | API Gateway モジュール |
| **API Gateway Resource Policy** | IP 制限（allowlist / denylist）のリソースポリシー | API Gateway モジュール |
| **EventBridge Schedule** | cron / rate 形式でのスケジュール実行 | Lambda モジュール |
| **SNS Topic（イベント）** | Lambda のトリガーとなる SNS トピック | **外部管理**（ARN を入力） |
| **SQS Queue（イベント）** | Lambda のトリガーとなる SQS キュー | **外部管理**（ARN を入力） |
| **CloudWatch Logs** | Lambda / API Gateway 実行ログ | 各モジュール |
| **CloudWatch Alarms** | Error / Throttle / Duration / Memory などのアラーム | 各モジュール |
| **SNS Alarm Topic** | アラーム通知用 SNS トピック | 各モジュール |
| **AWS Chatbot** | SNS → Slack 通知 | Chatbot モジュール |
| **VPC / Subnet** | Lambda の VPC 配置 | **外部管理**（ID を入力） |
| **Security Group** | Lambda 用セキュリティグループ | **外部管理** または Lambda モジュールで自動作成 |
| **DLQ / Destination** | 非同期実行失敗時の送信先 SQS/SNS | **外部管理**（ARN を入力） |
| **ACM 証明書** | カスタムドメイン用 TLS 証明書 | **外部管理**（ARN を入力） |
| **Route53 Hosted Zone** | カスタムドメイン用 DNS ゾーン | **外部管理**（Zone ID を入力） |

---

## 4. Terraform モジュール詳細

### 4.1 Lambda モジュール（`modules/lambda`）

#### 4.1.1 概要

Lambda 構築に必要な**すべてのリソース**を一括で作成する包括的なモジュールです。

ECR リポジトリ、Lambda 関数、CloudWatch 監視、IAM ロール、イベントソース設定まで、
Lambda 運用に必要なリソースを完全に自動化します。

詳細は [modules/lambda/README.md](./infra/terraform/modules/lambda/README.md) を参照してください。

#### 4.1.2 主な特徴

| 特徴 | 説明 |
|------|------|
| **コンテナイメージ専用** | ECR ベースの Docker イメージで Lambda を実行 |
| **JSON ログ固定** | CloudWatch Logs Insights での分析を容易に |
| **Fail Fast パターン** | リトライ 0 回、イベント有効期限 60 秒 |
| **Lambda Insights 対応** | CloudWatch Lambda Insights による詳細監視 |
| **X-Ray トレーシング** | 分散トレーシングによる性能分析（オプション） |
| **包括的なアラーム** | Error / Throttle / Duration / Memory / Invocation の5種類（Invocation は条件付き作成） |
| **イベントソース統合** | EventBridge / SNS / SQS トリガーの自動設定 |
| **デフォルトSG自動作成** | VPC使用時にSecurity Groupを自動作成（空リスト指定時） |

#### 4.1.3 管理するリソース

| リソース | 説明 |
|---------|------|
| **ECR Repository** | Lambda コンテナイメージの保管先 |
| **Lambda Function** | Lambda 本体（コンテナイメージ、JSON ログ、X-Ray 対応） |
| **Lambda Recursion Config** | 再帰実行の制御（Terminate に設定） |
| **Lambda Event Invoke Config** | 非同期実行の成功/失敗時の送信先設定 |
| **IAM Role** | Lambda 実行ロール |
| **IAM Policy Attachment** | 基本実行ポリシー、VPC ポリシー、Lambda Insights ポリシー |
| **CloudWatch Log Group** | Lambda のログ保存先（保持期間設定可能） |
| **CloudWatch Metric Filter** | MemorySize / MaxMemoryUsed の抽出 |
| **CloudWatch Alarms** | Error / Throttle / Duration / Invocation / Memory アラーム |
| **SNS Topic（Alarm）** | アラーム通知用の専用トピック |
| **EventBridge Schedule** | cron / rate 形式のスケジュール実行 |
| **SNS Subscription** | SNS トピック → Lambda のトリガー設定 |
| **SQS Event Source Mapping** | SQS → Lambda のイベントソース設定 |

#### 4.1.4 管理しないリソース

| リソース | 理由 | 管理元 |
|---------|------|--------|
| **SNS トピック本体** | 複数の Lambda や他サービスから利用される | 外部管理（ARN を入力） |
| **SQS キュー本体** | 同上 | 外部管理（ARN を入力） |
| **VPC / Subnet / SG** | Lambda 以外のリソースとも共有されるネットワーク基盤 | 外部管理（ID を入力） |
| **DLQ / Destination SQS/SNS** | 汎用的なキューで、Lambda 専用ではない | 外部管理（ARN を入力） |
| **API Gateway** | Lambda より上位の概念として別モジュール化 | API Gateway モジュール |

#### 4.1.5 主な設計制約

- **モジュール一つにつき Lambda 関数は一つ**（1対1対応）
- **ECR リポジトリも一つ**（Lambda と 1対1 対応）
- **コンテナイメージのみ対応**（ZIP パッケージは非対応）
- **JSON ログ形式固定**（テキストログは非対応）
- **Fail Fast パターン固定**（リトライ 0 回、イベント有効期限 60 秒）

---

### 4.2 API Gateway モジュール（`modules/apigateway`）

#### 4.2.1 概要

AWS API Gateway (REST API v1) を構築し、Lambda プロキシ統合と SQS 直接統合の両方に対応するモジュールです。

カスタムドメイン、API キー、使用量プラン、CloudWatch 監視まで、
API Gateway 運用に必要なリソースを完全に自動化します。

詳細は [modules/apigateway/README.md](./infra/terraform/modules/apigateway/README.md) を参照してください。

#### 4.2.2 主な特徴

| 特徴 | 説明 |
|------|------|
| **Lambda プロキシ統合** | Lambda 関数への自動プロキシ統合（AWS_PROXY） |
| **SQS 直接統合** | SQS へのダイレクト統合（AWS タイプ、非プロキシ） |
| **リソース階層自動生成** | パスから最大4階層までのリソースを自動作成 |
| **IP 制限機能** | リソースポリシーによる allowlist / denylist IP 制限 |
| **カスタムドメイン対応** | ACM 証明書 + Route53 レコードの自動設定 |
| **API キー & 使用量プラン** | スロットル・クオータ制御 |
| **包括的な監視** | 5XXError / 4XXError / Latency / Count のアラーム |
| **JSON アクセスログ** | CloudWatch Logs Insights での分析を容易に |

#### 4.2.3 管理するリソース

| リソース | 説明 |
|---------|------|
| **REST API 本体** | リージョナルエンドポイント（dualstack 対応） |
| **リソースポリシー（IP 制限）** | allowlist / denylist による IP アクセス制御 |
| **リソース階層** | パスから最大4階層までのリソースを自動生成 |
| **Lambda プロキシ統合** | メソッド定義 + Lambda 統合 + Invoke Permission |
| **SQS 直接統合** | メソッド定義 + SQS 統合 + IAM Role（SendMessage 権限） |
| **デプロイメント & ステージ** | 自動再デプロイ、アクセスログ、X-Ray トレーシング |
| **API キー & 使用量プラン** | API キー生成、スロットル・クオータ設定 |
| **カスタムドメイン** | ACM 証明書、ベースパスマッピング、Route53 レコード（A/AAAA） |
| **CloudWatch 監視** | アクセスログ、実行ログ、CloudWatch Alarms、SNS Topic |
| **IAM Role** | CloudWatch Logs 書き込み用、SQS 送信用 |

#### 4.2.4 管理しないリソース

| リソース | 理由 | 管理元 |
|---------|------|--------|
| **Lambda 関数本体** | Lambda の構築・監視は Lambda モジュールで一括管理 | Lambda モジュール |
| **SQS キュー本体** | 複数の API / Lambda から利用されうる | 外部管理（ARN を入力） |
| **ACM 証明書** | 複数のサービスで共有される | 外部管理（ARN を入力） |
| **Route53 Hosted Zone** | ドメイン全体の管理は外部で実施 | 外部管理（Zone ID を入力） |

#### 4.2.5 主な設計制約

- **モジュール一つにつきデプロイメントとステージは一つのみ**
- **API キーと使用量プランは1セットのみ**
- **スロットルはメソッドレベルでは指定しない**（使用量プラン全体で管理）
- **リソース階層は最大4階層まで対応**
- **Authorization は NONE 固定**（Cognito / Lambda オーソライザーは未実装）
- **REST API (v1) のみ対応**（HTTP API v2 は未対応）

---

### 4.3 Chatbot モジュール（`modules/chatbot`）

#### 4.3.1 概要

AWS Chatbot（Slack 連携）を構築し、CloudWatch アラームを Slack チャンネルに通知するモジュールです。

Lambda や API Gateway のアラーム SNS Topic を集約し、
一つの Slack チャンネルへ通知することで、監視を一元管理します。

詳細は [modules/chatbot/README.md](./infra/terraform/modules/chatbot/README.md) を参照してください。

#### 4.3.2 主な特徴

| 特徴 | 説明 |
|------|------|
| **通知専用設計** | Guardrail Policy（Deny All）により ChatOps コマンドを完全無効化 |
| **複数 SNS Topic 集約** | 複数のアラーム SNS Topic を一つの Slack チャンネルに集約 |
| **セキュアな運用** | すべての AWS API アクションを Deny することでリスクを最小化 |

#### 4.3.3 管理するリソース

| リソース | 説明 |
|---------|------|
| **Slack Channel Configuration** | Slack ワークスペース/チャンネルと AWS Chatbot の紐付け |
| **IAM Role** | Chatbot が Assume するロール |
| **Guardrail Policy** | すべてのアクションを Deny するポリシー（通知専用） |

#### 4.3.4 管理しないリソース

| リソース | 理由 | 管理元 |
|---------|------|--------|
| **SNS Topic 本体** | Lambda / API Gateway モジュールで作られたアラーム通知用 SNS を受け取る | Lambda / API Gateway モジュール |
| **Slack App 設定** | Slack 側での AWS Chatbot App のインストールは手動 | AWS Console（事前設定） |

#### 4.3.5 主な設計制約

- **モジュール一つにつき Slack チャンネル一つ**
- **ChatOps コマンドは完全に無効化**（Guardrail: Deny All）
- **Slack Workspace ID と Channel ID は事前設定が必要**

---

### 4.4 実装済みモジュール一覧

| モジュール | 状態 | 説明 |
|----------|------|------|
| **Lambda** | ✅ 実装済み | ECR + Lambda + CloudWatch + IAM + イベント設定の完全モジュール化 |
| **API Gateway** | ✅ 実装済み | REST API (v1) + Lambda/SQS 統合 + カスタムドメイン + 監視 |
| **Chatbot** | ✅ 実装済み | Slack 通知の自動化（通知専用、Deny All） |

---

### 4.5 未実装モジュール

以下のモジュールは今後実装予定です：

| モジュール | 用途 | 優先度 |
|----------|------|-------|
| **Step Functions** | Lambda のオーケストレーション | 高 |
| **WAF** | API Gateway の保護（レート制限、IP 制限など） | 中 |
| **CloudWatch Dashboard** | 監視ダッシュボードの自動構築 | 低 |

---

## 5. 開発環境（Docker Compose）

### 5.1 概要

`docker-compose.yml` には、ローカル開発用のコンテナが定義されています。

### 5.2 サービス一覧

| サービス名 | 用途 | ポート |
|-----------|------|-------|
| **`lambda-first`** | Lambda（first）のローカル実行テスト | `9001:8080` |
| **`lambda-second`** | Lambda（second）のローカル実行テスト | `9002:8080` |
| **`python`** | Python 実行環境（Lambda コード開発用） | - |
| **`sls-deploy`** | Serverless Framework デプロイ用（移行過渡期） | - |
| **`claude`** | Claude Code 実行環境 | - |

### 5.3 使い方

#### Lambda のローカル実行

```bash
# Lambda コンテナを起動
docker compose up lambda-first

# 別ターミナルから Lambda を呼び出し
curl -XPOST "http://localhost:9001/2015-03-31/functions/function/invocations" \
  -d '{"key":"value"}'
```

#### Python 開発環境

```bash
# Python コンテナに入る
docker compose run --rm python bash

# Lambda コードを編集・テスト
cd /serverless
python lambda_first.py
```

---

## 6. セットアップ手順

### 6.1 前提条件

以下がセットアップ済みであることを前提とします：

- **AWS アカウント**
- **AWS CLI** のインストールと設定（プロファイル設定）
- **Terraform >= 1.6.0**
- **Docker** のインストール（コンテナイメージビルド用）
- **Slack Workspace** と **AWS Chatbot App** の連携設定（Chatbot を使う場合）

### 6.2 事前に準備する AWS リソース

以下のリソースは **手動で作成** し、ARN や ID を Terraform 変数に入力します：

| リソース | 用途 | 参照先変数 |
|---------|------|-----------|
| **VPC / Subnet / Security Group** | Lambda を VPC 内で実行する場合 | `lambda_subnet_ids`, `lambda_security_group_ids` |
| **SQS Queue（DLQ）** | Lambda の Dead Letter Queue | `dlq_arn` |
| **SQS Queue（Failure）** | Event Invoke Config の失敗通知先 | `failure_queue_arn` |
| **SQS Queue（Success）** | Event Invoke Config の成功通知先 | `success_queue_arn` |
| **SQS Queue（Main）** | Lambda のイベントソース（メイン） | `queue_main_arn` |
| **SQS Queue（Second）** | Lambda のイベントソース（セカンド） | `queue_second_arn` |
| **SNS Topic（Main）** | Lambda のイベントソース | `sns_topic_main_arn` |
| **ACM 証明書** | API Gateway カスタムドメイン用 | `apigateway_first_acm_arn`, `apigateway_second_acm_arn` |
| **Route53 Hosted Zone** | API Gateway カスタムドメイン用 | `host_zone_id` |
| **Slack Team ID / Channel ID** | Chatbot 通知先 | `slack_team_id`, `slack_channel_id` |

### 6.3 Terraform 変数の設定

`infra/terraform/production/.production.tfvars` を作成し、以下のように設定します：

```hcl
# AWS プロファイル
profile = "your-aws-profile"

# Slack 通知設定
slack_team_id    = "TXXXXXXXX"
slack_channel_id = "CYYYYYYYY"

# VPC 設定（Lambda を VPC 内で実行する場合）
lambda_subnet_ids         = ["subnet-xxxxxx", "subnet-yyyyyy"]
lambda_security_group_ids = ["sg-xxxxxx"]

# SQS / SNS ARN
dlq_arn            = "arn:aws:sqs:ap-northeast-1:111111111111:your-dlq"
failure_queue_arn  = "arn:aws:sqs:ap-northeast-1:111111111111:your-failure-queue"
success_queue_arn  = "arn:aws:sqs:ap-northeast-1:111111111111:your-success-queue"
queue_main_arn     = "arn:aws:sqs:ap-northeast-1:111111111111:your-main-queue"
queue_second_arn   = "arn:aws:sqs:ap-northeast-1:111111111111:your-second-queue"
sns_topic_main_arn = "arn:aws:sns:ap-northeast-1:111111111111:your-main-topic"

# API Gateway カスタムドメイン設定
apigateway_first_domain_name  = "api1.example.com"
apigateway_first_acm_arn      = "arn:aws:acm:ap-northeast-1:111111111111:certificate/xxxxx"
apigateway_second_domain_name = "api2.example.com"
apigateway_second_acm_arn     = "arn:aws:acm:ap-northeast-1:111111111111:certificate/yyyyy"
host_zone_id                  = "Z1234567890ABC"
```

### 6.4 Terraform 実行手順

#### 1. Terraform 初期化

```bash
cd infra/terraform/production
terraform init
```

#### 2. Terraform フォーマット確認（任意）

```bash
terraform fmt -recursive
```

#### 3. Terraform 検証

```bash
terraform validate
```

#### 4. Terraform Plan

```bash
terraform plan -var-file=".production.tfvars"
```

#### 5. Terraform Apply

```bash
terraform apply -var-file=".production.tfvars"
```

### 6.5 GitHub Actions の設定（CI/CD 用）

CI/CD を有効にするには、GitHub リポジトリに以下の Secrets を設定します。

#### 6.5.1 必要な Secret

| Secret 名 | 説明 | 取得方法 |
|----------|------|---------|
| `AWS_ROLE_TO_ASSUME` | GitHub Actions が Assume する IAM Role の ARN | AWS IAM で OIDC プロバイダーと Role を作成 |

#### 6.5.2 AWS IAM Role の作成（OIDC 認証）

GitHub Actions から AWS にアクセスするため、OIDC 認証用の IAM Role を作成します。

**1. OIDC プロバイダーの作成**

AWS Console → IAM → ID プロバイダー → プロバイダーを追加

- プロバイダーのタイプ: `OpenID Connect`
- プロバイダーの URL: `https://token.actions.githubusercontent.com`
- 対象者: `sts.amazonaws.com`

**2. IAM Role の作成**

以下のような信頼ポリシーを持つ Role を作成します：

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::111111111111:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:your-org/serverless-terraform:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

**3. 必要な権限ポリシーをアタッチ**

以下の権限が必要です：

- ECR へのプッシュ権限
- Lambda 関数の更新権限

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "lambda:UpdateFunctionCode",
        "lambda:GetFunctionConfiguration"
      ],
      "Resource": "arn:aws:lambda:ap-northeast-1:111111111111:function:serverless-terraform-*"
    }
  ]
}
```

#### 6.5.3 GitHub Secrets の設定

GitHub リポジトリ → Settings → Secrets and variables → Actions → New repository secret

- Name: `AWS_ROLE_TO_ASSUME`
- Secret: `arn:aws:iam::111111111111:role/serverless-terraform-prod_ci_deploy`

---

## 7. Lambda コンテナイメージのビルド＆デプロイ

### 7.1 手動デプロイ手順

#### 7.1.1 Docker イメージのビルド

```bash
# lambda_first のビルド
docker buildx build \
  --platform linux/amd64 \
  --provenance=false \
  -t 111111111111.dkr.ecr.ap-northeast-1.amazonaws.com/serverless-terraform-lambda_first:latest \
  -f ./infra/docker/production/lambda_first/Dockerfile .

# lambda_second のビルド
docker buildx build \
  --platform linux/amd64 \
  --provenance=false \
  -t 111111111111.dkr.ecr.ap-northeast-1.amazonaws.com/serverless-terraform-lambda_second:latest \
  -f ./infra/docker/production/lambda_second/Dockerfile .
```

#### 7.1.2 ECR ログイン

```bash
aws ecr get-login-password --profile your-profile \
  | docker login --username AWS --password-stdin 111111111111.dkr.ecr.ap-northeast-1.amazonaws.com
```

#### 7.1.3 ECR Push

```bash
docker push 111111111111.dkr.ecr.ap-northeast-1.amazonaws.com/serverless-terraform-lambda_first:latest
docker push 111111111111.dkr.ecr.ap-northeast-1.amazonaws.com/serverless-terraform-lambda_second:latest
```

#### 7.1.4 Lambda の更新

Terraform で `image_tag` を変更して再 apply するか、以下のコマンドで Lambda を更新します：

```bash
aws lambda update-function-code \
  --function-name serverless-terraform-lambda_first \
  --image-uri 111111111111.dkr.ecr.ap-northeast-1.amazonaws.com/serverless-terraform-lambda_first:latest \
  --profile your-profile
```

### 7.2 CI/CD（GitHub Actions）

`.github/workflows/deployment.yml` には Lambda 用の CI/CD パイプラインが実装されています。

#### 7.2.1 ワークフローの概要

| 項目 | 内容 |
|------|------|
| **トリガー** | `main` ブランチへの push |
| **実行環境** | `ubuntu-latest` |
| **並列実行** | Matrix Strategy で複数 Lambda を並列処理 |
| **AWS 認証** | OIDC（OpenID Connect）による安全な認証 |

#### 7.2.2 処理フロー

```
1. main ブランチへの push
   ↓
2. Checkout（ソースコード取得）
   ↓
3. AWS 認証（OIDC）
   ↓
4. ECR ログイン
   ↓
5. Docker イメージのビルド
   ├─ lambda_first  (タグ: latest, GitHub SHA)
   └─ lambda_second (タグ: release, GitHub SHA)
   ↓
6. ECR へプッシュ
   ↓
7. Lambda 関数の更新
   ├─ serverless-terraform-lambda_first
   └─ serverless-terraform-lambda_second
```

#### 7.2.3 Matrix Strategy による並列実行

複数の Lambda 関数を並列でビルド・デプロイします：

```yaml
strategy:
  matrix:
    lambda:
      - name: lambda_first
        ecr_repository: serverless-terraform-lambda_first
        image_tag: latest
      - name: lambda_second
        ecr_repository: serverless-terraform-lambda_second
        image_tag: release
```

#### 7.2.4 イメージタグの管理

各 Lambda イメージには **2 つのタグ** が付与されます：

| タグ | 用途 |
|------|------|
| **指定タグ**（`latest` / `release`） | Terraform で参照するタグ |
| **GitHub SHA** | コミット単位のトレーサビリティ確保 |

例：
```
111111111111.dkr.ecr.ap-northeast-1.amazonaws.com/serverless-terraform-lambda_first:latest
111111111111.dkr.ecr.ap-northeast-1.amazonaws.com/serverless-terraform-lambda_first:a1b2c3d4
```

#### 7.2.5 新しい Lambda 関数を CI/CD に追加する方法

`.github/workflows/deployment.yml` の `matrix` セクションに追加します：

```yaml
strategy:
  matrix:
    lambda:
      - name: lambda_first
        ecr_repository: serverless-terraform-lambda_first
        image_tag: latest
      - name: lambda_second
        ecr_repository: serverless-terraform-lambda_second
        image_tag: release
      # 新しい Lambda を追加
      - name: lambda_third
        ecr_repository: serverless-terraform-lambda_third
        image_tag: latest
```

#### 7.2.6 注意事項

- **Terraform で Lambda を先に作成**: ワークフローの Step 7（Lambda 関数の更新）は、Terraform で Lambda が作成済みであることが前提です。Lambda が未作成の場合は、このステップをコメントアウトしてください。
- **IAM Role の権限**: GitHub Actions が使用する IAM Role には、ECR プッシュと Lambda 更新の権限が必要です（セクション 6.5.2 参照）

---

## 8. 運用ガイド

### 8.1 新しい Lambda 関数の追加

#### 8.1.1 Lambda コードの作成

```bash
# serverless ディレクトリに新しい Lambda 関数を作成
vi serverless/lambda_third.py
```

```python
import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

def handler(event, context):
    logger.info("Event: %s", json.dumps(event))
    logger.info("Third!")
    return {"statusCode": 200, "body": "Hello from Lambda Third!"}
```

#### 8.1.2 Dockerfile の作成

```bash
# 本番環境用の Dockerfile を作成
vi infra/docker/production/lambda_third/Dockerfile
```

```dockerfile
FROM public.ecr.aws/lambda/python:3.13

# Install CloudWatch Lambda Insights Extension
RUN curl -O https://lambda-insights-extension.s3-ap-northeast-1.amazonaws.com/amazon_linux/lambda-insights-extension.rpm && \
    rpm -U lambda-insights-extension.rpm && \
    rm -f lambda-insights-extension.rpm

# Copy requirements.txt & Install the specified packages
COPY ./serverless /build
RUN pip install --upgrade pip
RUN if [ -f /build/requirements.txt ]; then pip install -r /build/requirements.txt; fi
RUN rm -rf /build

# Copy function code
COPY ./serverless/lambda_third.py ${LAMBDA_TASK_ROOT}

# Set the CMD to your handler
CMD [ "lambda_third.handler" ]
```

#### 8.1.3 Terraform 設定の追加

`infra/terraform/production/locals.tf` に Lambda 設定を追加：

```hcl
locals {
  # ...既存設定...

  lambda_third = {
    function_name       = "${local.project}-lambda_third"
    ecr_repository_name = "${local.project}-lambda_third"
  }
}
```

`infra/terraform/production/modules.tf` にモジュール呼び出しを追加：

```hcl
module "lambda_third" {
  source = "../modules/lambda"

  project = local.project

  function_name       = local.lambda_third.function_name
  ecr_repository_name = local.lambda_third.ecr_repository_name
}
```

#### 8.1.4 デプロイ

```bash
# Terraform でインフラを作成
cd infra/terraform/production
terraform apply -var-file=".production.tfvars"

# Docker イメージをビルド＆プッシュ
docker buildx build \
  --platform linux/amd64 \
  --provenance=false \
  -t 111111111111.dkr.ecr.ap-northeast-1.amazonaws.com/serverless-terraform-lambda_third:latest \
  -f ./infra/docker/production/lambda_third/Dockerfile .

docker push 111111111111.dkr.ecr.ap-northeast-1.amazonaws.com/serverless-terraform-lambda_third:latest
```

**CI/CD を使う場合：**

上記の手動デプロイではなく、`.github/workflows/deployment.yml` の `matrix` に追加すれば、`main` ブランチへの push で自動デプロイされます（セクション 7.2.5 参照）。

---

### 8.2 新しい API Gateway の追加

#### 8.2.1 Terraform 設定の追加

`infra/terraform/production/locals.tf` に API Gateway 設定を追加：

```hcl
locals {
  # ...既存設定...

  apigateway_third = {
    name        = "${local.project}-apigateway_third"
    domain_name = var.apigateway_third_domain_name

    lambda_proxy_methods = {
      all = {
        path               = "/{proxy+}"
        http_method        = "ANY"
        lambda_module_name = "lambda_third"
      }
    }
  }
}
```

`infra/terraform/production/modules.tf` にモジュール呼び出しを追加：

```hcl
module "apigateway_third" {
  source = "../modules/apigateway"

  project = local.project
  name    = local.apigateway_third.name

  enable_custom_domain = local.flags.apigateway_third.enable_custom_domain
  domain_name          = local.apigateway_third.domain_name
  acm_certificate_arn  = var.apigateway_third_acm_arn
  zone_id              = var.host_zone_id

  lambda_proxy_methods = [
    for method_key, method_val in local.apigateway_third.lambda_proxy_methods :
    {
      path        = method_val.path
      http_method = method_val.http_method
      lambda_arn  = local.lambda_function_arns[method_val.lambda_module_name]
    }
  ]
}
```

#### 8.2.2 デプロイ

```bash
cd infra/terraform/production
terraform apply -var-file=".production.tfvars"
```

---

### 8.3 環境変数の設定

`infra/terraform/production/environments.tf` で Lambda の環境変数を管理します：

```hcl
locals {
  lambda_environments = {
    lambda_first = {
      APP_NAME      = local.project
      FUNCTION_NAME = local.lambda_first.function_name
      DB_HOST       = "https://example.com"
    }
    lambda_second = {
      APP_NAME      = local.project
      FUNCTION_NAME = local.lambda_second.function_name
      API_KEY       = "your-api-key"
    }
  }
}
```

その後、`modules.tf` でモジュールに渡します：

```hcl
module "lambda_first" {
  source = "../modules/lambda"

  # ...他の設定...
  environment_variables = local.lambda_environments.lambda_first
}
```

---

### 8.4 アラームの調整

`infra/terraform/production/locals.tf` でアラーム閾値を調整します：

#### Lambda アラーム

```hcl
locals {
  lambda_second = {
    # ...他の設定...
    error_alarm_threshold      = 5      # Error が 5 回以上で通知
    throttle_alarm_threshold   = 3      # Throttle が 3 回以上で通知
    memory_alarm_threshold     = 90     # メモリ使用率 90% 以上で通知
    duration_alarm_threshold   = 20000  # 実行時間 20 秒以上で通知
    invocation_alarm_threshold = 10000  # 実行回数 10000 回以上で通知
  }
}
```

#### API Gateway アラーム

```hcl
locals {
  apigateway_second = {
    # ...他の設定...
    stage_alarm_config = {
      five_xx_error_threshold = 5      # 5XXエラーが5回以上で通知
      four_xx_error_threshold = 100    # 4XXエラーが100回以上で通知
      latency_threshold_ms    = 2000   # レイテンシ2秒以上で通知
      count_threshold         = 10000  # リクエスト数10000以上で通知
    }
  }
}
```

---

### 8.5 VPC / X-Ray の有効化

`infra/terraform/production/flags.tf` で機能フラグを管理します：

```hcl
locals {
  flags = {
    lambda_second = {
      use_vpc  = true   # VPC 内で実行
      use_xray = true   # X-Ray トレーシングを有効化
    }
    apigateway_second = {
      enable_custom_domain              = true   # カスタムドメインを有効化
      use_xray                          = true   # X-Ray トレーシングを有効化
      manage_apigw_account_logging_role = false  # アカウントレベルのロギングRoleを管理しない
    }
  }
}
```

---

## 9. 設計思想と制約

### 9.1 モジュールの責務分離

| 設計原則 | 説明 |
|---------|------|
| **Lambda モジュール** | Lambda の構築・監視・イベント設定を包括的に管理 |
| **API Gateway モジュール** | REST API の構築・統合・カスタムドメイン・監視を管理 |
| **Chatbot モジュール** | アラーム通知を Slack に送信 |
| **外部依存** | VPC / SNS / SQS / ACM / Route53 などの汎用リソースは外部で管理 |

### 9.2 依存関係の管理

依存関係を **上下関係** で整理し、循環依存を防止します：

```
┌─────────────────────┐
│  API Gateway        │  ← 上位モジュール（Lambda を呼び出す側）
│  Step Functions     │     Lambda Invoke Permission は API Gateway 側で管理
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  Lambda Module      │  ← 中心モジュール
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  VPC / SNS / SQS    │  ← 下位リソース（汎用基盤）
└─────────────────────┘
```

### 9.3 モジュール設計の共通原則

#### 9.3.1 一つのモジュール = 一つのメインリソース

- **Lambda モジュール**: 一つの Lambda 関数 + 一つの ECR リポジトリ
- **API Gateway モジュール**: 一つの REST API + 一つのデプロイメント/ステージ
- **Chatbot モジュール**: 一つの Slack チャンネル

複数のリソースが必要な場合は、モジュールを複数作成します。

#### 9.3.2 汎用リソースは外部管理

VPC、SNS、SQS、ACM 証明書、Route53 Hosted Zone など、
複数のモジュールやサービスで共有されるリソースは、モジュール外で管理します。

#### 9.3.3 上位モジュールが下位リソースのポリシーを管理

API Gateway が Lambda を呼び出す場合、
Lambda Invoke Permission（リソースポリシー）は **API Gateway モジュール側で管理** します。

これにより、循環依存を回避し、依存関係を明確にします。

### 9.4 制約事項

| 制約 | 理由 |
|------|------|
| **S3 トリガーは非推奨** | S3 は 1 通知設定しか持てないため、SNS 経由を推奨 |
| **VPC / SNS / SQS は外部管理** | 複数の Lambda やサービスで共有されるため |
| **Terraform State はローカル** | 現在は `terraform.tfstate` がローカルに保存されているが、**本来は S3 バックエンド推奨** |
| **Lambda はコンテナイメージのみ** | ZIP パッケージは非対応（起動速度とイメージサイズの観点から） |
| **JSON ログ固定** | CloudWatch Logs Insights での分析を容易にするため |

---

## 10. 今後の予定

### 10.1 完了済み

| 項目 | 完了日 | 説明 |
|------|-------|------|
| **Lambda モジュール** | ✅ | ECR + Lambda + CloudWatch + IAM + イベント設定の完全モジュール化 |
| **Lambda VPC SG 自動作成** | ✅ 2025-12 | VPC 使用時に Security Group を自動作成する機能を追加 |
| **Lambda Invocation アラーム条件化** | ✅ 2025-12 | Invocation アラームを条件付きで作成（null 指定時は作成しない） |
| **API Gateway モジュール** | ✅ | REST API (v1) + Lambda/SQS 統合 + カスタムドメイン + 監視 |
| **API Gateway IP 制限** | ✅ 2025-12 | リソースポリシーによる IP 制限機能（allowlist / denylist）を追加 |
| **Chatbot モジュール** | ✅ | Slack 通知の自動化 |
| **CI/CD の整備** | ✅ | GitHub Actions による自動デプロイ（Docker ビルド → ECR プッシュ → Lambda 更新） |
| **モジュールドキュメント** | ✅ | 各モジュールの包括的な README の整備 |

### 10.2 実装予定

| 項目 | 優先度 | 説明 |
|------|-------|------|
| **Step Functions モジュール** | 高 | Lambda のオーケストレーションを Terraform 化 |
| **Terraform Backend の S3 化** | 高 | State ファイルを S3 に保存し、複数人での運用を可能に |
| **Staging 環境の分離** | 中 | `production` と `staging` ディレクトリを分ける |
| **WAF モジュール** | 中 | API Gateway の保護（レート制限、IP 制限など） |
| **CloudWatch Dashboard モジュール** | 低 | 監視ダッシュボードの自動構築 |
| **Datadog 連携** | 低 | Datadog による統合監視 |

### 10.3 技術的負債

| 項目 | 対応予定 |
|------|---------|
| **Terraform State の共有** | S3 バックエンド + DynamoDB ロックの設定 |
| **Secrets 管理** | AWS Secrets Manager / Parameter Store との連携 |
| **Terraform の変数管理** | 環境変数や機密情報を `.tfvars` ファイルから分離 |
| **API Gateway の CI/CD** | API 定義変更時の自動デプロイ |

---

## 補足

### 参考リンク

- [Terraform AWS Lambda Module（公式）](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function)
- [Terraform AWS API Gateway Resources（公式）](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/api_gateway_rest_api)
- [AWS Lambda コンテナイメージ（公式）](https://docs.aws.amazon.com/lambda/latest/dg/images-create.html)
- [AWS API Gateway（公式）](https://docs.aws.amazon.com/apigateway/latest/developerguide/)
- [AWS Chatbot（公式）](https://docs.aws.amazon.com/chatbot/latest/adminguide/what-is.html)

### トラブルシューティング

#### Terraform で ECR イメージが見つからないエラー

```
Error: error creating Lambda Function: InvalidParameterValueException:
The image with imageId 111111111111.dkr.ecr.ap-northeast-1.amazonaws.com/...:latest does not exist
```

**原因**: ECR にイメージがプッシュされていない

**対応**: 先に Docker イメージをビルド＆プッシュしてから `terraform apply` を実行

#### Lambda が VPC 内で起動しない

**原因**: Subnet や Security Group の設定が不正

**対応**:
- Subnet は **プライベートサブネット** を指定
- NAT Gateway / VPC Endpoint が設定されているか確認
- Security Group でアウトバウンド通信が許可されているか確認

#### CloudWatch Alarms が発火しない

**原因**: アラーム閾値が高すぎる、または SNS サブスクリプションが未設定

**対応**:
- `locals.tf` でアラーム閾値を調整
- Chatbot モジュールが正しく SNS Topic を購読しているか確認

#### API Gateway で 5XX エラーが発生する

**原因**: Lambda の実行権限が不足している、またはタイムアウト

**対応**:
- Lambda の実行ロールに必要な権限があるか確認
- Lambda のタイムアウト設定を確認（API Gateway は最大 29 秒）
- CloudWatch Logs で Lambda の実行ログを確認

#### API Gateway のカスタムドメインが反映されない

**原因**: ACM 証明書のリージョンが異なる、または DNS レコードが未反映

**対応**:
- ACM 証明書は API Gateway と **同じリージョン** で作成されているか確認
- Route53 レコードが正しく作成されているか確認
- DNS の伝播には時間がかかるため、数分待つ

---

## ライセンス

このプロジェクトは社内プロジェクトであり、ライセンスは未定義です。

---

以上が、`serverless-terraform` プロジェクトの包括的なドキュメントです。

各モジュールの詳細については、以下の個別ドキュメントを参照してください：

- [Lambda モジュール](./infra/terraform/modules/lambda/README.md)
- [API Gateway モジュール](./infra/terraform/modules/apigateway/README.md)
- [Chatbot モジュール](./infra/terraform/modules/chatbot/README.md)
