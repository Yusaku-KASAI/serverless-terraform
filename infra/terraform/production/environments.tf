locals {
  lambda_environments = {
    lambda_first = {
      APP_NAME      = local.project
      FUNCTION_NAME = local.lambda_first.function_name
      # 他に必要な環境変数があればここに追加
      # DB_HOST = "https://example.com"
    }
    lambda_second = {
      APP_NAME      = local.project
      FUNCTION_NAME = local.lambda_second.function_name
      # 他に必要な環境変数があればここに追加
      # DB_HOST = "https://example.com"
    }
  }
}
