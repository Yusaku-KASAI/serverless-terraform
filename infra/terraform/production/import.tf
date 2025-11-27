#### ECR ####
import {
  to = module.lambda_first.aws_ecr_repository.this
  id = local.lambda_first.ecr_repository_name
}

import {
  to = module.lambda_second.aws_ecr_repository.this
  id = local.lambda_second.ecr_repository_name
}
