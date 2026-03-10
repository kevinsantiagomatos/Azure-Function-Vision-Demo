import json
import logging
import os
from typing import Any, Dict, List

import azure.functions as func
from azure.cosmos import CosmosClient

COSMOS_ENDPOINT = os.getenv("COSMOS_ENDPOINT")
COSMOS_KEY = os.getenv("COSMOS_KEY")
COSMOS_DB_NAME = os.getenv("COSMOS_DB_NAME", "imagedb")
COSMOS_CONTAINER_NAME = os.getenv("COSMOS_CONTAINER_NAME", "metadata")

_cosmos_container = None


def _get_container():
    global _cosmos_container
    if _cosmos_container is None:
        client = CosmosClient(COSMOS_ENDPOINT, credential=COSMOS_KEY)
        _cosmos_container = client.get_database_client(COSMOS_DB_NAME).get_container_client(
            COSMOS_CONTAINER_NAME
        )
    return _cosmos_container


def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info("ApiList function processed a request.")
    tag = req.params.get("tag")
    limit = int(req.params.get("limit", "50"))
    container = _get_container()

    query = "SELECT TOP @limit c.id, c.filename, c.thumbnail, c.thumbnail_url, c.image_url, c.tags, c.caption, c.size_bytes FROM c"
    parameters: List[Dict[str, Any]] = [{"name": "@limit", "value": limit}]

    if tag:
        query += " WHERE ARRAY_CONTAINS(c.tags, @tag)"
        parameters.append({"name": "@tag", "value": tag})

    items = list(container.query_items(query=query, parameters=parameters, enable_cross_partition_query=True))

    return func.HttpResponse(
        body=json.dumps({"items": items}),
        status_code=200,
        mimetype="application/json",
    )
