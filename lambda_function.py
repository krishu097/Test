import json
import os
import urllib.request

def lambda_handler(event, context):
    print("Event:", json.dumps(event))

    GITHUB_OWNER = os.environ["GITHUB_REPO_OWNER"]
    GITHUB_REPO = os.environ["GITHUB_REPO"]
    GITHUB_TOKEN = os.environ["GITHUB_TOKEN"]

    # Trigger GitHub workflow
    url = f"https://api.github.com/repos/{GITHUB_OWNER}/{GITHUB_REPO}/actions/workflows/mlops-pipeline.yaml/dispatches"

    # Extract S3 info from event
    record = event["Records"][0]
    bucket = record["s3"]["bucket"]["name"]
    key = record["s3"]["object"]["key"]
    
    data = json.dumps({
        "ref": "main",
        "inputs": {
            "s3_bucket": bucket,
            "s3_key": key
        }
    }).encode("utf-8")

    req = urllib.request.Request(url, data=data, method="POST")
    req.add_header("Accept", "application/vnd.github+json")
    req.add_header("Authorization", f"token {GITHUB_TOKEN}")
    req.add_header("Content-Type", "application/json")

    try:
        response = urllib.request.urlopen(req)
        print("GitHub API status:", response.status)
        return {"statusCode": 200, "body": "Workflow triggered"}

    except Exception as e:
        print("Error triggering workflow:", str(e))
        return {"statusCode": 500, "body": "Failed to trigger workflow"}
