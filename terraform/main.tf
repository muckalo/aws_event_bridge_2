provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region = var.region
}

# SQS
resource "aws_sqs_queue" "sqs-queue-1" {
  name = "agrcic-sqs-queue-${var.part}"
}


# EVENT BRIDGE
# Create EventBridge Rule
resource "aws_cloudwatch_event_rule" "eb-rule-1" {
  name = "agrcic-eb-rule-${var.part}"
  event_pattern = jsonencode({
    source = ["com.myapp.sqs"]
    detail-type = ["agrcic-detail-type-${var.part}"]
  })
  depends_on = [aws_sqs_queue.sqs-queue-1]
}
# Create EventBridge Target
resource "aws_cloudwatch_event_target" "eb-target-1" {
  arn  = aws_sqs_queue.sqs-queue-1.arn
  rule = aws_cloudwatch_event_rule.eb-rule-1.name
  depends_on = [aws_cloudwatch_event_rule.eb-rule-1]
  target_id = "agrcic-target-${var.part}"
}
# Grant EventBridge Permissions to Send Messages to SQS
resource "aws_sqs_queue_policy" "event_queue_policy" {
  queue_url = aws_sqs_queue.sqs-queue-1.id
  depends_on = [aws_cloudwatch_event_target.eb-target-1]
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "agrcic-EventBridgeSendMessage-${var.part}",
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action = "SQS:SendMessage"
        Resource = aws_sqs_queue.sqs-queue-1.arn
        Condition = {
          "ArnEquals" = {
            "aws:SourceArn" = aws_cloudwatch_event_rule.eb-rule-1.arn
          }
        }
      }
    ]
  })
}




# Lambda
# resource "aws_iam_role" "lambda_role-1" {
#   name = "agrcic-lambda-role-${var.part}"
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Sid = "agrcic-lambda-policy-${var.part}"
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
