# API Gateway REST API
resource "aws_api_gateway_rest_api" "dofs_api" {
  name        = "${var.project_name}-${var.environment}-api"
  description = "Distributed Order Fulfillment System API"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# API Gateway Resource for /order
resource "aws_api_gateway_resource" "order_resource" {
  rest_api_id = aws_api_gateway_rest_api.dofs_api.id
  parent_id   = aws_api_gateway_rest_api.dofs_api.root_resource_id
  path_part   = "order"
}

# POST method for /order
resource "aws_api_gateway_method" "order_post" {
  rest_api_id   = aws_api_gateway_rest_api.dofs_api.id
  resource_id   = aws_api_gateway_resource.order_resource.id
  http_method   = "POST"
  authorization = "NONE"

  request_validator_id = aws_api_gateway_request_validator.validator.id

  request_models = {
    "application/json" = aws_api_gateway_model.order_model.name
  }
}

# OPTIONS method for CORS
resource "aws_api_gateway_method" "order_options" {
  rest_api_id   = aws_api_gateway_rest_api.dofs_api.id
  resource_id   = aws_api_gateway_resource.order_resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# Request validator
resource "aws_api_gateway_request_validator" "validator" {
  name                        = "${var.project_name}-${var.environment}-validator"
  rest_api_id                 = aws_api_gateway_rest_api.dofs_api.id
  validate_request_body       = true
  validate_request_parameters = true
}

# Request model for order validation
resource "aws_api_gateway_model" "order_model" {
  rest_api_id  = aws_api_gateway_rest_api.dofs_api.id
  name         = "OrderModel"
  content_type = "application/json"

  schema = jsonencode({
    "$schema" = "http://json-schema.org/draft-04/schema#"
    title     = "Order Schema"
    type      = "object"
    required  = ["customerId", "productId", "quantity", "price"]
    properties = {
      customerId = {
        type    = "string"
        pattern = "^CUST-\\d{4,}$"
      }
      productId = {
        type    = "string"
        pattern = "^PROD-\\d{4,}$"
      }
      quantity = {
        type    = "integer"
        minimum = 1
        maximum = 100
      }
      price = {
        type    = "number"
        minimum = 0.01
        maximum = 10000
      }
      metadata = {
        type = "object"
      }
    }
  })
}

# Lambda integration for POST /order
resource "aws_api_gateway_integration" "order_post_integration" {
  rest_api_id = aws_api_gateway_rest_api.dofs_api.id
  resource_id = aws_api_gateway_resource.order_resource.id
  http_method = aws_api_gateway_method.order_post.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "arn:aws:apigateway:${data.aws_region.current.name}:lambda:path/2015-03-31/functions/${var.api_handler_lambda_arn}/invocations"

  depends_on = [aws_lambda_permission.api_gateway_lambda]
}

# CORS integration for OPTIONS
resource "aws_api_gateway_integration" "order_options_integration" {
  rest_api_id = aws_api_gateway_rest_api.dofs_api.id
  resource_id = aws_api_gateway_resource.order_resource.id
  http_method = aws_api_gateway_method.order_options.http_method

  type = "MOCK"

  request_templates = {
    "application/json" = "{'statusCode': 200}"
  }
}

# CORS response for OPTIONS
resource "aws_api_gateway_method_response" "order_options_response" {
  rest_api_id = aws_api_gateway_rest_api.dofs_api.id
  resource_id = aws_api_gateway_resource.order_resource.id
  http_method = aws_api_gateway_method.order_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "order_options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.dofs_api.id
  resource_id = aws_api_gateway_resource.order_resource.id
  http_method = aws_api_gateway_method.order_options.http_method
  status_code = aws_api_gateway_method_response.order_options_response.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

# Lambda permission for API Gateway
resource "aws_lambda_permission" "api_gateway_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = var.api_handler_lambda_function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.dofs_api.execution_arn}/*/*"
}

# API Gateway Deployment
resource "aws_api_gateway_deployment" "dofs_deployment" {
  depends_on = [
    aws_api_gateway_integration.order_post_integration,
    aws_api_gateway_integration.order_options_integration
  ]

  rest_api_id = aws_api_gateway_rest_api.dofs_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.order_resource.id,
      aws_api_gateway_method.order_post.id,
      aws_api_gateway_method.order_options.id,
      aws_api_gateway_integration.order_post_integration.id,
      aws_api_gateway_integration.order_options_integration.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# API Gateway Stage
resource "aws_api_gateway_stage" "dofs_stage" {
  deployment_id = aws_api_gateway_deployment.dofs_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.dofs_api.id
  stage_name    = var.environment

  xray_tracing_enabled = true

  tags = {
    Name        = "${var.project_name}-${var.environment}-api-stage"
    Project     = var.project_name
    Environment = var.environment
  }
}

data "aws_region" "current" {}
