provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region = var.region
}

# SQS
resource "aws_sqs_queue" "sqs-queue-1" {
  name = "agrcic-sqs-queue-1-${var.part}"
}


# EVENT BRIDGE
# Create Role for EventBridge
resource "aws_iam_role" "eventbridge_role" {
  name = "agrcic-eventbridge-role-1-${var.part}"

  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "events.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  })
}
# Create Polivy for EventBridge
resource "aws_iam_role_policy" "eventbridge_policy" {
  name   = "agrcic-eventbridge-policy-1-${var.part}"
  role   = aws_iam_role.eventbridge_role.id

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": "sqs:SendMessage",
        "Resource": aws_sqs_queue.sqs-queue-1.arn
      }
    ]
  })
}


# Create EventBridge Rule
resource "aws_cloudwatch_event_rule" "eb-rule-1" {
  name = "agrcic-eb-rule-1-${var.part}"
  event_pattern = jsonencode({
    source = ["demo.sqs"]
  })
  depends_on = [aws_sqs_queue.sqs-queue-1]
}
# Create EventBridge Target
resource "aws_cloudwatch_event_target" "eb-target-1" {
  rule = aws_cloudwatch_event_rule.eb-rule-1.name
  arn  = aws_sqs_queue.sqs-queue-1.arn
  depends_on = [aws_cloudwatch_event_rule.eb-rule-1]
  target_id = "agrcic-target-1-${var.part}"
  role_arn = aws_iam_role.eventbridge_role.arn
}
# Grant EventBridge Permissions to Send Messages to SQS
resource "aws_sqs_queue_policy" "event_queue_policy" {
  queue_url = aws_sqs_queue.sqs-queue-1.id
  depends_on = [aws_cloudwatch_event_target.eb-target-1]
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "agrcic-EventBridgeSendMessage-1-${var.part}",
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
#   name = "agrcic-lambda-role-1-${var.part}"
#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Sid = "agrcic-lambda-policy-1-${var.part}"
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
#   function_name = "agrcic-lambda-1-${var.part}"
#   handler = "lambda_1.lambda_handler"
#   runtime = "python3.9"
#   role = aws_iam_role.lambda_role-1.arn
#   source_code_hash = filebase64sha256("../lambda_functions.zip")
#   filename = "../lambda_functions.zip"
# }
# resource "aws_lambda_function" "agrcic-lambda-2" {
#   function_name = "agrcic-lambda-2-${var.part}"
#   handler = "lambda_2.lambda_handler"
#   runtime = "python3.9"
#   role = aws_iam_role.lambda_role-1.arn
#   source_code_hash = filebase64sha256("../lambda_functions.zip")
#   filename = "../lambda_functions.zip"
# }
