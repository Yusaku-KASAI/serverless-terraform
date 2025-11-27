import json
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def handler(event, context):
    logger.info("Event: %s", json.dumps(event))

    logger.info("Second!")
    return {"statusCode": 200, "body": "Hello from Lambda!"}
