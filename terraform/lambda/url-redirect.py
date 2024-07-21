import boto3
import os
from botocore.exceptions import ClientError

# DynamoDB Table Name
DYNAMODB_TABLE = os.environ['DYNAMODB_TABLE']

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(DYNAMODB_TABLE)

def lambda_handler(event, context):
    # path값에 존재하는 short_id 값
    short_id = event['pathParameters']['short_id']
    
    try:
        # short_id 값을 바탕으로 검색
        response = table.get_item(
            Key={
                'short_id': short_id
            }
        )
    except ClientError as e:
        print(e.response['Error']['Message'])
        return {
            'statusCode': 500,
            'body': 'Internal Server Error'
        }

    if 'Item' not in response:
        return {
            'statusCode': 404,
            'body': 'Not Found'
        }

    # 검색한 item 값 바탕으로 변환 전 original_url
    original_url = response['Item']['original_url']

    return {
        'statusCode': 301,
        'headers': {
            'Location': original_url
        }
    }
