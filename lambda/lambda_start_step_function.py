import json
import boto3
import os


AWS_REGION = "eu-west-1"
session = boto3.session.Session()
step_function_client = session.client(
    service_name='stepfunctions',
    region_name=AWS_REGION
)


def lambda_handler(event, context):
    print("Lambda start step function received event:", json.dumps(event))

    step_function_arn = os.environ['STEP_FUNCTION_ARN']

    for record in event['Records']:
        # Assuming the SQS message body is a JSON string
        message_body = json.loads(record['body'])

        # You can modify this payload as necessary for your Step Function
        payload = {
            "choice": message_body.get('choice', '3'),  # Example key; modify as needed
            # Add more keys as necessary
        }
        print("payload:", payload)

        response = step_function_client.start_execution(
            stateMachineArn=step_function_arn,
            input=json.dumps(payload)
        )

        print(f'Started execution with ARN: {response["executionArn"]}')

    return {
        'statusCode': 200,
        'body': json.dumps('Step Function execution started.')
    }
