###### flag for using modules and resources ######
locals {
  flags = {
    lambda_second = {
      use_vpc  = true
      use_xray = true
    }

    apigateway_first = {
      enable_custom_domain = true
    }

    apigateway_second = {
      enable_custom_domain              = true
      use_xray                          = true
      manage_apigw_account_logging_role = false
    }
  }
}
