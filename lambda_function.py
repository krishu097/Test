import json
import os
import urllib3

http = urllib3.PoolManager()

GITHUB_TOKEN = os.getenv("GITHUB_TOKEN")
OWNER = os.getenv("GITHUB_REPO_OWNER")
REPO = os.getenv("GITHUB_REPO")

def lambda_handler(event, context):
    print("Event:", event)

    record = event["Records"][0]
    bucket = record["s3"]["bucket"]["name"]
    key    = record["s3"]["object"]["key"]

    if not key.endswith(".csv"):
        return {"msg": "Ignored non-CSV file", "file": key}

    print(f"CSV uploaded: s3://{bucket}/{key}")
    print(f"Triggering GitHub workflow for repo {OWNER}/{REPO}")

    url = f"https://api.github.com/repos/{OWNER}/{REPO}/actions/workflows/mlops-pipeline.yaml/dispatches"

    body = {
        "ref": "main",
        "inputs": {
            "s3_bucket": bucket,
            "s3_key": key
        }
    }

    headers = {
        "Authorization": f"Bearer {GITHUB_TOKEN}",
        "User-Agent": "lambda-mlops-trigger",
        "Accept": "application/vnd.github+json"
    }

    response = http.request(
        "POST",
        url,
        headers=headers,
        body=json.dumps(body)
    )

    print("GitHub API status:", response.status)

    return {
        "status": "success",
        "github_response": response.status
    }

