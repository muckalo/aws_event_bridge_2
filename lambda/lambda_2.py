"""
Lambda 2
"""

import json


def lambda_handler(event, context):
    """
    Lambda Handler - Test 2

    :param event:
    :param context:
    :return:
    """

    # Log the received event
    print("Lambda 2 received event:", json.dumps(event))

    # Process the event
    result = {
        "status": "success",
        "message": "Processed by Lambda 2",
        "input": event
    }

    return result
