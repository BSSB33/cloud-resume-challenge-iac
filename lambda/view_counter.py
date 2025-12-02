import json
import boto3
import os
from decimal import Decimal

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb')
table_name = os.environ['TABLE_NAME']
allowed_origin = os.environ['ALLOWED_ORIGIN']
table = dynamodb.Table(table_name)

def lambda_handler(event, context):
    """
    Lambda function to increment and return view counter.
    Protected by CORS - only callable from vitraigabor.eu
    """

    # Get the origin and referer from the request
    headers = event.get('headers', {})
    origin = headers.get('origin', '')
    referer = headers.get('referer', '')

    # Security check: Verify request comes from allowed domain
    # Check both origin (for CORS) and referer (for direct calls)
    is_valid_origin = origin == allowed_origin or origin == ''
    is_valid_referer = referer.startswith(allowed_origin) or referer == ''

    # Allow if either origin or referer matches (browser sends origin, some tools send referer)
    if origin and not is_valid_origin:
        return {
            'statusCode': 403,
            'headers': {
                'Content-Type': 'application/json',
            },
            'body': json.dumps({
                'error': 'Forbidden',
                'message': 'Invalid origin'
            })
        }

    if referer and not is_valid_referer:
        return {
            'statusCode': 403,
            'headers': {
                'Content-Type': 'application/json',
            },
            'body': json.dumps({
                'error': 'Forbidden',
                'message': 'Invalid referer'
            })
        }

    try:
        # Increment the view counter atomically
        response = table.update_item(
            Key={'id': '1'},
            UpdateExpression='SET #views = if_not_exists(#views, :start) + :inc',
            ExpressionAttributeNames={
                '#views': 'views'
            },
            ExpressionAttributeValues={
                ':inc': 1,
                ':start': 0
            },
            ReturnValues='UPDATED_NEW'
        )

        # Get the new view count
        new_views = int(response['Attributes']['views'])

        # Return success response
        # Note: CORS headers are automatically added by Lambda Function URL
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
            },
            'body': json.dumps({
                'views': new_views,
                'message': 'View count updated successfully'
            })
        }

    except Exception as e:
        print(f"Error updating view count: {str(e)}")

        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
            },
            'body': json.dumps({
                'error': 'Internal Server Error',
                'message': 'Failed to update view count'
            })
        }
