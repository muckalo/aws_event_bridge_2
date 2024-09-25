provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region = var.region
}

# SQS
resource "aws_sqs_queue" "event_queue" {
  name = "agrcic-event-queue"
}

# EventBridge
resource "aws_cloudwatch_event_rule" "event_rule" {
  name        = "agrcic-eventbridge-to-sqs-rule"
  event_pattern = jsonencode({
    source = ["com.myapp.sqs"]
  })
}
resource "aws_cloudwatch_event_target" "sqs_target" {
  rule      = aws_cloudwatch_event_rule.event_rule.name
  arn       = aws_sqs_queue.event_queue.arn
  # Set the input transformation if needed
  # @TODO: Add target if needed
}

# Permissions SQS
resource "aws_sqs_queue_policy" "event_queue_policy" {
  queue_url = aws_sqs_queue.event_queue.id
  depends_on = [aws_cloudwatch_event_target.sqs_target]
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid = "agrcic-EventBridgeSendMessage",
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action = "SQS:SendMessage"
        Resource = aws_sqs_queue.event_queue.arn
        Condition = {
          "ArnEquals" = {
            "aws:SourceArn" = aws_cloudwatch_event_rule.event_rule.arn
          }
        }
      }
    ]
  })
}

# Lambda
resource "aws_lambda_function" "lambda_function_1" {
  function_name = "agrcic_lambda_function_1"
  handler       = "lambda_1.lambda_handler"
  runtime       = "python3.9"  # Change as needed
  role          = aws_iam_role.lambda_exec_role.arn
  filename      = "../lambda_functions.zip"
}

resource "aws_lambda_function" "lambda_function_2" {
  function_name = "agrcic_lambda_function_2"
  handler       = "lambda_2.lambda_handler"
  runtime       = "python3.9"  # Change as needed
  role          = aws_iam_role.lambda_exec_role.arn
  filename      = "../lambda_functions.zip"
}

# Permission Lambda
resource "aws_iam_role" "lambda_exec_role" {
  name = "agrcic-lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Effect = "Allow"
        Sid    = ""
      }
    ]
  })
}

# StepFunction
resource "aws_sfn_state_machine" "state_machine" {
  name     = "agrcic-MyStateMachine"
  role_arn = aws_iam_role.step_function_role.arn

  definition = jsonencode({
    StartAt = "CheckCondition",
    States = {
      CheckCondition = {
        Type = "Choice",
        Choices = [
          {
            Variable = "$.condition",
            StringEquals = "1",
            Next = "InvokeLambda1"
          },
          {
            Variable = "$.condition",
            StringEquals = "2",
            Next = "InvokeLambda2"
          }
        ],
        Default = "FailState"
      },
      InvokeLambda1 = {
        Type = "Task",
        Resource = aws_lambda_function.lambda_function_1.arn,
        End = true
      },
      InvokeLambda2 = {
        Type = "Task",
        Resource = aws_lambda_function.lambda_function_2.arn,
        End = true
      },
      FailState = {
        Type = "Fail",
        Error = "ConditionNotMet",
        Cause = "No matching condition found"
      }
    }
  })
}

resource "aws_iam_role" "step_function_role" {
  name = "agrcic-step_function_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole",
        Principal = {
          Service = "states.amazonaws.com"
        }
        Effect = "Allow"
        Sid    = ""
      }
    ]
  })
}

# Set SQS as trigger for StepFunction
# resource "aws_lambda_event_source_mapping" "sqs_trigger" {
#   event_source_arn = aws_sqs_queue.event_queue.arn
#   function_arn     = aws_lambda_function.lambda_function_1.arn  # Placeholder, not directly triggering in this way.
#   batch_size       = 10
#   enabled          = true
# }
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.event_queue.arn
  function_name    = aws_lambda_function.lambda_function_1.function_name
}

