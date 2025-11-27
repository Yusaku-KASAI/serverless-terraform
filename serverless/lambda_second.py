import json
import logging
import random
import time

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def handler(event, context):
    logger.info("Event: %s", json.dumps(event))

    logger.info("Second!")

    if random.random() < 0.3:
        time.sleep(2)
        raise Exception("Random failure occurred in lambda_second")

    return {"statusCode": 200, "body": "Hello from Lambda!"}
