import os
import requests
import json

api_key = "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"
url = "https://integrate.api.nvidia.com/v1/chat/completions"

headers = {
    "Authorization": f"Bearer {api_key}",
    "Content-Type": "application/json"
}

payload = {
    "model": "meta/llama-3.3-70b-instruct",
    "messages": [
        {"role": "user", "content": "Hello, are you working?"}
    ],
    "max_tokens": 50
}

try:
    response = requests.post(url, headers=headers, json=payload)
    print(f"Status Code: {response.status_code}")
    print(json.dumps(response.json(), indent=2))
except Exception as e:
    print(f"Error: {e}")
