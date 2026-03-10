import io
import logging
import os
import uuid
from typing import List

import azure.functions as func
from azure.storage.blob import BlobServiceClient, ContentSettings
from azure.cosmos import CosmosClient
from azure.cosmos.exceptions import CosmosHttpResponseError
from PIL import Image
from msrest.authentication import CognitiveServicesCredentials
from azure.cognitiveservices.vision.computervision import ComputerVisionClient
from azure.cognitiveservices.vision.computervision.models import VisualFeatureTypes

# Environment / configuration
VISION_ENDPOINT = os.getenv("VISION_ENDPOINT")
VISION_KEY = os.getenv("VISION_KEY")
COSMOS_ENDPOINT = os.getenv("COSMOS_ENDPOINT")
COSMOS_KEY = os.getenv("COSMOS_KEY")
COSMOS_DB_NAME = os.getenv("COSMOS_DB_NAME", "imagedb")
COSMOS_CONTAINER_NAME = os.getenv("COSMOS_CONTAINER_NAME", "metadata")
IMAGE_CONTAINER = os.getenv("IMAGE_CONTAINER", "images")
THUMBNAIL_CONTAINER = os.getenv("THUMBNAIL_CONTAINER", "thumbnails")

# Clients (lazy init)
_blob_client = None
_cosmos_container = None
_cv_client = None


def _get_blob_service_client() -> BlobServiceClient:
    global _blob_client
    if _blob_client is None:
        connection_string = os.getenv("AzureWebJobsStorage")
        _blob_client = BlobServiceClient.from_connection_string(connection_string)
    return _blob_client


def _get_cosmos_container():
    global _cosmos_container
    if _cosmos_container is None:
        cosmos_client = CosmosClient(COSMOS_ENDPOINT, credential=COSMOS_KEY)
        _cosmos_container = cosmos_client.get_database_client(COSMOS_DB_NAME).get_container_client(
            COSMOS_CONTAINER_NAME
        )
    return _cosmos_container


def _get_cv_client() -> ComputerVisionClient:
    global _cv_client
    if _cv_client is None:
        creds = CognitiveServicesCredentials(VISION_KEY)
        _cv_client = ComputerVisionClient(VISION_ENDPOINT, creds)
    return _cv_client


def _make_thumbnail(image_bytes: bytes, max_size: int = 256) -> bytes:
    with Image.open(io.BytesIO(image_bytes)) as img:
        img = img.convert("RGB")
        img.thumbnail((max_size, max_size))
        out = io.BytesIO()
        img.save(out, format="JPEG", optimize=True, quality=85)
        return out.getvalue()


def _upload_thumbnail(blob_name: str, data: bytes, content_type: str):
    blob_service = _get_blob_service_client()
    thumb_blob = blob_service.get_blob_client(container=THUMBNAIL_CONTAINER, blob=blob_name)
    thumb_blob.upload_blob(
        data,
        overwrite=True,
        content_settings=ContentSettings(content_type=content_type),
    )


def _analyze_image(image_bytes: bytes) -> dict:
    client = _get_cv_client()
    analysis = client.analyze_image_in_stream(io.BytesIO(image_bytes), visual_features=[
        VisualFeatureTypes.tags,
        VisualFeatureTypes.description,
    ])

    tags: List[str] = [t.name for t in analysis.tags if t.confidence >= 0.5]
    caption = None
    if analysis.description and analysis.description.captions:
        caption = analysis.description.captions[0].text

    return {"tags": tags, "caption": caption}


def _persist_metadata(item: dict):
    container = _get_cosmos_container()
    try:
        container.upsert_item(item)
    except CosmosHttpResponseError:
        logging.exception("Failed to upsert Cosmos document")
        raise


def main(blob: func.InputStream):
    logging.info("Processing blob: %s (%d bytes)", blob.name, blob.length)
    image_bytes = blob.read()

    # Derive names
    filename = os.path.basename(blob.name)
    thumb_name = f"thumb-{filename.rsplit('.', 1)[0]}.jpg"

    # Make thumbnail and upload
    thumb_bytes = _make_thumbnail(image_bytes)
    _upload_thumbnail(thumb_name, thumb_bytes, content_type="image/jpeg")

    # Analyze image
    analysis = _analyze_image(image_bytes)

    # Persist metadata
    doc = {
        "id": str(uuid.uuid4()),
        "filename": filename,
        "thumbnail": thumb_name,
        "tags": analysis.get("tags", []),
        "caption": analysis.get("caption"),
        "size_bytes": blob.length,
    }

    # Blob URLs (help frontend)
    account = _get_blob_service_client().account_name
    base_url = f"https://{account}.blob.core.windows.net"
    doc["image_url"] = f"{base_url}/{IMAGE_CONTAINER}/{filename}"
    doc["thumbnail_url"] = f"{base_url}/{THUMBNAIL_CONTAINER}/{thumb_name}"

    _persist_metadata(doc)
    logging.info("Upserted metadata for %s", filename)
