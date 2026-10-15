import json
import boto3
import os
import time
from datetime import datetime, timezone
from decimal import Decimal

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb')
table_name = os.environ['TABLE_NAME']
rate_limit_table_name = os.environ['RATE_LIMIT_TABLE_NAME']
allowed_origins = [o.strip() for o in os.environ['ALLOWED_ORIGINS'].split(',')]
counting_origin = os.environ['COUNTING_ORIGIN']
table = dynamodb.Table(table_name)
rate_limit_table = dynamodb.Table(rate_limit_table_name)

# Rate limit configuration - 1 hour window
RATE_LIMIT_WINDOW_SECONDS = 3600

# Item id of the all-time counter
TOTAL_COUNTER_ID = '1'

def current_week_id():
    """Item id of the current ISO week's counter (UTC, weeks start on Monday), e.g. 'week#2026-W42'.
    Uses the ISO year, which can differ from the calendar year around New Year."""
    year, week, _ = datetime.now(timezone.utc).isocalendar()
    return f"week#{year}-W{week:02d}"

def increment_counter(item_id):
    """Atomically increment a counter item (created on first use) and return the new value."""
    response = table.update_item(
        Key={'id': item_id},
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
    return int(response['Attributes']['views'])

def read_counter(item_id):
    """Return a counter's value, or 0 if the item doesn't exist yet (e.g. a new week)."""
    item = table.get_item(Key={'id': item_id}).get('Item')
    return int(item['views']) if item else 0

def lambda_handler(event, context):
    """
    Lambda function to increment and return view counter.
    Protected by CORS - only callable from vitraigabor.eu
    """

    # Get the origin and referer from the request
    headers = event.get('headers', {})
    origin = headers.get('origin', '')
    referer = headers.get('referer', '')

    # Security check: Verify request comes from an allowed domain
    # Check both origin (for CORS) and referer (for direct calls)
    is_valid_origin = origin == '' or origin in allowed_origins
    is_valid_referer = referer == '' or any(referer.startswith(o) for o in allowed_origins)

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

        # Only count visits originating from the resume subdomain
        is_counting_origin = origin == counting_origin or referer.startswith(counting_origin)

        # Determine if we should increment based on client request and rate limiting
        perform_increment = should_increment and not rate_limited and is_counting_origin

        week_id = current_week_id()

        if perform_increment:
            # Increment the all-time counter atomically
            new_views = increment_counter(TOTAL_COUNTER_ID)

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
        else:
            # Just get the current count without incrementing
            new_views = read_counter(TOTAL_COUNTER_ID)

        # Weekly counter is best-effort: a failure here must not hide the all-time count
        week_views = None
        try:
            week_views = increment_counter(week_id) if perform_increment else read_counter(week_id)
        except Exception as e:
            print(f"Weekly counter error: {e}")

        # Return success response
        # Note: CORS headers are automatically added by Lambda Function URL
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
            },
            'body': json.dumps({
                'views': new_views,
                'week_views': week_views,
                'week': week_id.split('#', 1)[1],
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
