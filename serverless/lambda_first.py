import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def handler(event, context):
    logger.info("Event: %s", json.dumps(event))

    logger.info("First!")
    return {"statusCode": 200, "body": "Hello from Lambda!"}
