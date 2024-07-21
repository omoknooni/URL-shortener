import base64
import boto3
import os
import hashlib
from botocore.exceptions import ClientError
import json

# DynamoDB Table Name
DYNAMODB_TABLE = os.environ['DYNAMODB_TABLE']

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(DYNAMODB_TABLE)

def lambda_handler(event, context):
    obj = event['body']

    if type(obj) is not dict:
        obj = json.loads(obj)

    original_url = obj['params']['url']

    # Generate a unique short ID
    short_id = generate_short_id(original_url)
    
    # Store the mapping in DynamoDB
    try:
        table.put_item(
            Item={
                'short_id': short_id,
                'original_url': original_url
            }
        )
    except ClientError as e:
        print(e.response['Error']['Message'])
        return {
            'statusCode': 500,
            'body': 'Internal Server Error'
        }

    # Return the short URL
    short_url = f"https://url.omoknooni.link/a/{short_id}"
    return {
        'statusCode': 200,
        'body': short_url
    }

def generate_short_id(url):
    # Use SHA-256 to generate a hash of the URL
    url_hash = hashlib.sha256(url.encode()).digest()
    # Encode the hash in URL-safe base64
    url_base64 = base64.urlsafe_b64encode(url_hash).decode()
    # Return the first 7 characters
    return url_base64[:7]