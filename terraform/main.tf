provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region = var.region
}

# SQS
# Create SQS Queue
resource "aws_sqs_queue" "sqs-queue-1" {
  name = "agrcic-sqs-queue-1-${var.part}"
}


# EVENT BRIDGE
# Create CloudWatch Log Group For EventBridge
resource "aws_cloudwatch_log_group" "eb-rule-log-group-1" {
  name = "/aws/events/agrcic-eb-rule-1-${var.part}"
}
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
# Create Policy for EventBridge to send messages to SQS
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
# Create Policy for EventBridge to send logs to CloudWatch
resource "aws_iam_role_policy" "eventbridge_policy_2" {
  name   = "agrcic-eventbridge-policy-2"
  role   = aws_iam_role.eventbridge_role.id
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource": "arn:aws:logs:*:*:log-group:/aws/events/*"
      }
    ]
  })
}

# Create EventBridge Rule
resource "aws_cloudwatch_event_rule" "eb-rule-1" {
  name = "agrcic-eb-rule-1-${var.part}"
  event_pattern = jsonencode({
    source = ["demo.sqs"]
    detail = {
      choice = ["1", "2", "3"]  # Example choices to trigger
    }
  })
  depends_on = [aws_sqs_queue.sqs-queue-1]
}
# Create EventBridge Target for SQS
resource "aws_cloudwatch_event_target" "eb-target-1" {
  rule = aws_cloudwatch_event_rule.eb-rule-1.name
  target_id = "agrcic-target-1-${var.part}"
  arn  = aws_sqs_queue.sqs-queue-1.arn
  depends_on = [aws_cloudwatch_event_rule.eb-rule-1]
  input_transformer {
      input_paths = {
        choice = "$.detail.choice"  # Adjust this based on your event structure
      }
      input_template = jsonencode({
        choice = choice
      })
    }
}
# Create EventBridge Target for CloudWatch
resource "aws_cloudwatch_event_target" "eb-target-cw-1" {
  rule      = aws_cloudwatch_event_rule.eb-rule-1.name
  target_id = "agrcic-target-cw-1-${var.part}"
  arn = aws_cloudwatch_log_group.eb-rule-log-group-1.arn
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
# Create Policy for Sending Events to EventBridge
resource "aws_iam_role_policy" "eventbridge_policy_3" {
  name   = "agrcic-eventbridge-policy-3"
  role   = aws_iam_role.eventbridge_role.id
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": "events:PutEvents",
        "Resource": "arn:aws:events:${var.region}:${data.aws_caller_identity.current.account_id}:event-bus/default"
      }
    ]
  })
}


# Lambda
resource "aws_iam_role" "lambda_role_1" {
  name = "agrcic-lambda-role-1-${var.part}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "sts:AssumeRole"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}
# Create Role for Lambda to be able to create Logs
resource "aws_iam_policy" "lambda_logging_policy" {
  name        = "agrcic-lambda-logging-policy1--${var.part}"
  description = "Policy for allowing Lambda to write logs to CloudWatch"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      }
    ]
  })
}
# Attach policy
resource "aws_iam_role_policy_attachment" "lambda_logging_policy_policy_attachment" {
  role       = aws_iam_role.lambda_role_1.name
  policy_arn = aws_iam_policy.lambda_logging_policy.arn
}

# Create Lambda Function to Start the Step Function
resource "aws_lambda_function" "start_step_function" {
  function_name = "agrcic-lambda-start-step-function-1-${var.part}"
  handler       = "lambda_start_step_function.lambda_handler" # Adjust based on your handler
  runtime       = "python3.9"
  role          = aws_iam_role.lambda_role_1.arn
  source_code_hash = filebase64sha256("../lambda_functions.zip") # Adjust the path as necessary
  filename      = "../lambda_functions.zip" # Adjust the path as necessary

  environment {
    variables = {
      STEP_FUNCTION_ARN = aws_sfn_state_machine.agrcic_state_machine_1.arn
    }
  }
}
# Add permission for Lambda to read from SQS
resource "aws_iam_role_policy" "lambda_sqs_policy" {
  name   = "agrcic-lambda-sqs-policy-1-${var.part}"
  role   = aws_iam_role.lambda_role_1.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = "sqs:ReceiveMessage",
        Resource = aws_sqs_queue.sqs-queue-1.arn
      },
      {
        Effect = "Allow",
        Action = [
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ],
        Resource = aws_sqs_queue.sqs-queue-1.arn
      }
    ]
  })
}
# Add permission for Lambda to start execution of State Machine
resource "aws_iam_role_policy" "lambda_step_function_policy" {
  name   = "agrcic-lambda-step-function-policy-1-${var.part}"
  role   = aws_iam_role.lambda_role_1.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = "states:StartExecution",
        Resource = aws_sfn_state_machine.agrcic_state_machine_1.arn
      }
    ]
  })
}

# Event Source Mapping for SQS to Trigger Lambda
resource "aws_lambda_event_source_mapping" "sqs_to_lambda" {
  event_source_arn = aws_sqs_queue.sqs-queue-1.arn
  function_name    = aws_lambda_function.start_step_function.arn
  enabled          = true
  batch_size       = 10
}


resource "aws_lambda_function" "agrcic-lambda-1" {
  function_name = "agrcic-lambda-1-${var.part}"
  handler = "lambda_1.lambda_handler"
  runtime = "python3.9"
  role = aws_iam_role.lambda_role_1.arn
  source_code_hash = filebase64sha256("../lambda_functions.zip")
  filename = "../lambda_functions.zip"
}
resource "aws_lambda_function" "agrcic-lambda-2" {
  function_name = "agrcic-lambda-2-${var.part}"
  handler = "lambda_2.lambda_handler"
  runtime = "python3.9"
  role = aws_iam_role.lambda_role_1.arn
  source_code_hash = filebase64sha256("../lambda_functions.zip")
  filename = "../lambda_functions.zip"
}
resource "aws_lambda_function" "agrcic-lambda-3" {
  function_name = "agrcic-lambda-3-${var.part}"
  handler = "lambda_3.lambda_handler"
  runtime = "python3.9"
  role = aws_iam_role.lambda_role_1.arn
  source_code_hash = filebase64sha256("../lambda_functions.zip")
  filename = "../lambda_functions.zip"
}


# STEP FUNCTION
# Create Role for Step Function
resource "aws_iam_role" "step_function_role" {
  name = "agrcic-step-function-role-1-${var.part}"

  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "states.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  })
}
# Attach policy to allow Step Function to invoke Lambda functions
resource "aws_iam_role_policy" "step_function_policy_1" {
  name = "agrcic-step-function-policy-1-${var.part}"
  role = aws_iam_role.step_function_role.id

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "lambda:InvokeFunction"
        ],
        "Resource": [
          aws_lambda_function.agrcic-lambda-1.arn,
          aws_lambda_function.agrcic-lambda-2.arn,
          aws_lambda_function.agrcic-lambda-3.arn
        ]
      }
    ]
  })
}
# Create Step Function State Machine
resource "aws_sfn_state_machine" "agrcic_state_machine_1" {
  name     = "agrcic-state-machine-1-${var.part}"
  role_arn = aws_iam_role.step_function_role.arn

  definition = jsonencode({
    "Comment": "A simple AWS Step Function example with choices",
    "StartAt": "ChoiceState",
    "States": {
      "ChoiceState": {
        "Type": "Choice",
        "Choices": [
          {
            "Variable": "$.choice",
            "StringEquals": "1",
            "Next": "InvokeLambda1"
          },
          {
            "Variable": "$.choice",
            "StringEquals": "2",
            "Next": "InvokeLambda2"
          }
        ],
        "Default": "InvokeLambda3"
      },
      "InvokeLambda1": {
        "Type": "Task",
        "Resource": aws_lambda_function.agrcic-lambda-1.arn,
        "End": true
      },
      "InvokeLambda2": {
        "Type": "Task",
        "Resource": aws_lambda_function.agrcic-lambda-2.arn,
        "End": true
      },
      "InvokeLambda3": {
        "Type": "Task",
        "Resource": aws_lambda_function.agrcic-lambda-3.arn,
        "End": true
      }
    }
  })
}
