"""
Lambda start StepFunction
"""

import os
import json
import boto3


AWS_REGION = "eu-west-1"
session = boto3.session.Session()
step_function_client = session.client(
    service_name='stepfunctions',
    region_name=AWS_REGION
)
sqs_client = session.client(
    service_name='sqs',
    region_name=AWS_REGION
)
dlq_url = os.environ['DLQ_URL']


def lambda_handler(event, context):
    """
    Lambda Handler - Test start StepFunction

    :param event:
    :param context:
    :return:
    """

    print("Lambda start step function received event:", json.dumps(event))

    step_function_arn = os.environ['STEP_FUNCTION_ARN']

    for record in event['Records']:
        try:
            # Assuming the SQS message body is a JSON string
            message_body = json.loads(record['body'])

            # Extract choice from the message body
            choice = message_body.get('choice', '')

            # Check if choice is a string
            if not choice:
                err_msg = "Missing key 'choice' in body"
                print(err_msg)
                raise ValueError(err_msg)

            # You can modify this payload as necessary for your Step Function
            payload = {
                "choice": choice,
            }
            print("payload:", payload)

            response = step_function_client.start_execution(
                stateMachineArn=step_function_arn,
                input=json.dumps(payload)
            )

            print(f'Started execution with ARN: {response["executionArn"]}')

        except Exception as e:
            # Create a DLQ message with error information
            dlq_payload = {
                "error": str(e),
                "input": record,
                "function_name": context.function_name,
                "timestamp": context.aws_request_id
            }
            # Send to DLQ
            sqs_client.send_message(
                QueueUrl=dlq_url,
                MessageBody=json.dumps(dlq_payload)
            )

    return {
        'statusCode': 200,
        'body': json.dumps('Step Function execution started.')
    }
