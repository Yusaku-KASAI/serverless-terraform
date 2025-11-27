###### flag for using modules and resources ######
locals {
  flags = {
    lambda_second = {
      use_vpc  = true
      use_xray = true
    }
  }
}
