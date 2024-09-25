provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region = var.region
}

# SQS
resource "aws_sqs_queue" "sqs-queue-1" {
  name = "agrcic-sqs-queue-1"
}

# EventBridge
resource "aws_cloudwatch_event_rule" "eb-rule-1" {
  name = "agrcic-eb-rule-1"
  event_pattern = jsonencode({
    source = ["com.myapp.sqs"]
  })
  depends_on = [aws_sqs_queue.sqs-queue-1]
}
resource "aws_cloudwatch_event_target" "eb-target-1" {
  event_bus_name = "agrcic-event-bus-1"
  arn  = aws_sqs_queue.sqs-queue-1.arn
  rule = aws_cloudwatch_event_rule.eb-rule-1.name
  depends_on = [aws_cloudwatch_event_rule.eb-rule-1]
}

# Lambda
# resource "aws_iam_role" "lambda_role-1" {
#   name = "agrcic-lambda-role-1"
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Sid = "agrcic-lambda-policy-1"
#         Effect = "Allow"
#         Action = "sts:AssumeRole"
#         Principal = {
#           Service = "lambda.amazonaws.com"
#         }
#       }
#     ]
#   })
# }
# resource "aws_lambda_function" "agrcic-lambda-1" {
#   function_name = "agrcic-lambda-1"
#   handler = "lambda_1.lambda_handler"
#   runtime = "python3.9"
#   role = aws_iam_role.lambda_role-1.arn
#   source_code_hash = filebase64sha256("../lambda_functions.zip")
#   filename = "../lambda_functions.zip"
# }
# resource "aws_lambda_function" "agrcic-lambda-2" {
#   function_name = "agrcic-lambda-2"
#   handler = "lambda_2.lambda_handler"
#   runtime = "python3.9"
#   role = aws_iam_role.lambda_role-1.arn
#   source_code_hash = filebase64sha256("../lambda_functions.zip")
#   filename = "../lambda_functions.zip"
# }
