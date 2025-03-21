import json
import boto3
import pymysql
import os

def lambda_handler(event, context):
    try:                
        print("event")
        print(event)
        return {
            'statusCode': 200,
            'body': 'Record inserted successfully'
        }
    except Exception as e:
        print(e)
        return {
            'statusCode': 500,
            'body': str(e)
        }