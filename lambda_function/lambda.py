import base64
import json

def lambda_handler(event, context):
    output_records = []
    
    # Process each record in the batch
    for record in event['records']:
        # Decode the incoming data
        payload = base64.b64decode(record['data']).decode('utf-8')
        
        # Parse the JSON data (assuming data is in JSON format)
        try:
            data = json.loads(payload)
            
            # Example transformation - add a timestamp field
            # and convert some fields to uppercase
            transformed_data = transform_record(data)
            
            # Convert back to JSON string
            transformed_payload = json.dumps(transformed_data)
            
            # Encode as base64
            encoded_payload = base64.b64encode(transformed_payload.encode('utf-8')).decode('utf-8')
            
            # Add to output with "Ok" status
            output_record = {
                'recordId': record['recordId'],
                'result': 'Ok',
                'data': encoded_payload
            }
        except Exception as e:
            # Failed processing - pass the record through as is
            output_record = {
                'recordId': record['recordId'],
                'result': 'ProcessingFailed',
                'data': record['data']
            }
        
        output_records.append(output_record)
    
    return {'records': output_records}

def transform_record(data):
    """
    Apply transformations to the record data.
    Customize this function for your specific transformation needs.
    """
    # Example transformations:
    
    # 1. Add processing timestamp
    from datetime import datetime
    data['processing_timestamp'] = datetime.now().isoformat()
    
    # 2. Convert certain fields to uppercase (if they exist)
    if 'message' in data:
        data['message'] = data['message'].upper()
    
    # 3. Filter out sensitive fields
    if 'password' in data:
        del data['password']
    
    # 4. Add a new calculated field
    if 'value1' in data and 'value2' in data:
        try:
            data['calculated'] = float(data['value1']) * float(data['value2'])
        except (ValueError, TypeError):
            pass
    
    # 5. Restructure data (example)
    if 'nested' in data and isinstance(data['nested'], dict):
        for key, value in data['nested'].items():
            data[f'flat_{key}'] = value
    
    return data