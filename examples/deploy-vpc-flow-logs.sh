#!/bin/bash
# This script creates a Honeycomb lambda function that listens to a Cloudwatch
# Log Group receiving VPC Flow Logs and sends them to a Honeycomb dataset.

ENVIRONMENT=production
STACK_NAME=${ENVIRONMENT}-vpc-flow-logs
# change this to the log group name used by your VPC flow logs
LOG_GROUP_NAME=/aws/vpc/${ENVIRONMENT}-flow-logs
# this is the base64-encoded KMS encrypted CiphertextBlob containing your write key
# To encrypt your key, run `aws kms encrypt --key-id $MY_KMS_KEY_ID --plaintext "$MY_HONEYCOMB_KEY"`
# paste the CyphertextBlob here
HONEYCOMB_WRITE_KEY=CHANGEME
# this is the KMS Key ID used to encrypt the write key above
# try running `aws kms list-keys` - you want the UID after ":key/" in the ARN
KMS_KEY_ID=CHANGEME
DATASET="vpc-flow-logs"
# VPC flow logs can contain a lot of data - sampling is recommended!
HONEYCOMB_SAMPLE_RATE="100"
TEMPLATE="file://../templates/cloudwatch-logs-regex.yml"
REGEX_PATTERN="(?P<version>\d+) (?P<account_id>\d+) (?P<interface_id>eni-[0-9a-f]+) (?P<src_addr>[\d\.]+) (?P<dst_addr>[\d\.]+) (?P<src_port>\d+) (?P<dst_port>\d+) (?P<protocol>\d+) (?P<packets>\d+) (?P<bytes>\d+) (?P<start_time>\d+) (?P<end_time>\d+) (?P<action>[A-Z]+) (?P<log_status>[A-Z]+)"

# Sending regex is terrible - use a JSON cli input, and run it through jq to
# escape the regex pattern correctly
JSON=$(cat << END
{
    "StackName": "${STACK_NAME}",
    "Parameters": [
        {
            "ParameterKey": "Environment",
            "ParameterValue": "${ENVIRONMENT}"
        },
        {
            "ParameterKey": "HoneycombWriteKey",
            "ParameterValue": "${HONEYCOMB_WRITE_KEY}"
        },
        {
            "ParameterKey": "KMSKeyId",
            "ParameterValue": "${KMS_KEY_ID}"
        },
        {
            "ParameterKey": "HoneycombDataset",
            "ParameterValue": "${DATASET}"
        },
        {
            "ParameterKey": "HoneycombSampleRate",
            "ParameterValue": "${HONEYCOMB_SAMPLE_RATE}"
        },
        {
            "ParameterKey": "LogGroupName",
            "ParameterValue": "${LOG_GROUP_NAME}"
        },
        {
            "ParameterKey": "RegexPattern",
            "ParameterValue": \$regex
        },
        {
            "ParameterKey": "TimeFieldName",
            "ParameterValue": "start_time"
        },
        {
            "ParameterKey": "TimeFieldFormat",
            "ParameterValue": "%s(%L)?"
        }
    ],
    "Capabilities": [
        "CAPABILITY_IAM"
    ],
    "OnFailure": "ROLLBACK",
    "Tags": [
        {
            "Key": "Environment",
            "Value": "${ENVIRONMENT}"
        }
    ]
}
END
)

JSON=$(jq -n --arg regex "${REGEX_PATTERN}" "$JSON")

aws cloudformation create-stack --cli-input-json "${JSON}" --template-body=${TEMPLATE}
