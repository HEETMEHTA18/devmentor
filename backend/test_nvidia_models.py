import os
import requests
import json

api_key = "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"

url = "https://integrate.api.nvidia.com/v1/models"
headers = {
    "Authorization": f"Bearer {api_key}",
    "Content-Type": "application/json"
}

try:
    response = requests.get(url, headers=headers)
    models = response.json().get('data', [])
    for m in models:
        if 'meta' in m['id']:
            print(m['id'])
except Exception as e:
    print(f"Error: {e}")
