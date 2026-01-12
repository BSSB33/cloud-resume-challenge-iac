import json
import boto3
import os
import time
from decimal import Decimal

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb')
table_name = os.environ['TABLE_NAME']
rate_limit_table_name = os.environ['RATE_LIMIT_TABLE_NAME']
allowed_origin = os.environ['ALLOWED_ORIGIN']
table = dynamodb.Table(table_name)
rate_limit_table = dynamodb.Table(rate_limit_table_name)

# Rate limit configuration - 1 hour window
RATE_LIMIT_WINDOW_SECONDS = 3600

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

    # Parse request body to check if frontend wants to increment
    should_increment = True
    try:
        if event.get('body'):
            body = json.loads(event['body'])
            should_increment = body.get('increment', True)
    except (json.JSONDecodeError, KeyError):
        # If body parsing fails, default to incrementing
        pass

    # Get client IP for rate limiting
    request_context = event.get('requestContext', {})
    http_context = request_context.get('http', {})
    client_ip = http_context.get('sourceIp', 'unknown')

    # If IP is unknown, fall back to headers
    if client_ip == 'unknown':
        client_ip = headers.get('x-forwarded-for', 'unknown').split(',')[0].strip()

    try:
        current_time = int(time.time())
        ttl_timestamp = current_time + 86400  # 24 hours from now

        # Check if IP has recently incremented (rate limiting)
        rate_limited = False
        if should_increment and client_ip != 'unknown':
            try:
                rate_limit_response = rate_limit_table.get_item(Key={'ip': client_ip})

                if 'Item' in rate_limit_response:
                    last_increment_time = int(rate_limit_response['Item']['timestamp'])

                    # Check if within rate limit window
                    if current_time - last_increment_time < RATE_LIMIT_WINDOW_SECONDS:
                        rate_limited = True
                        print(f"Rate limited IP: {client_ip}")
            except Exception as e:
                print(f"Rate limit check error: {e}")
                # Continue anyway - don't block on rate limit failures

        # Determine if we should increment based on client request and rate limiting
        perform_increment = should_increment and not rate_limited

        if perform_increment:
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

            # Update rate limit record
            if client_ip != 'unknown':
                try:
                    rate_limit_table.put_item(
                        Item={
                            'ip': client_ip,
                            'timestamp': current_time,
                            'ttl': ttl_timestamp
                        }
                    )
                except Exception as e:
                    print(f"Failed to update rate limit: {e}")
                    # Don't fail the request if rate limit update fails

            # Get the new view count
            new_views = int(response['Attributes']['views'])
        else:
            # Just get the current count without incrementing
            response = table.get_item(Key={'id': '1'})
            new_views = int(response['Item']['views'])

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
