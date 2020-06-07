import logging
from time import time

from mygpoclient.api import MygPodderClient
from mygpoclient.public import PublicClient

import datastore
from secrets_config import SecretsConfig

logger = logging.getLogger("gpodder")


def fetch_episode_actions(config: SecretsConfig) -> None:
    client = MygPodderClient(config.gpodder_username, config.gpodder_password)
    max_action = datastore.max_action() or time() - (60 * 60 * 24 * 45)
    hours = (time() - max_action) / 60 / 60
    logger.info(f"Fetching actions from the past {int(hours)} hours")
    response = client.download_episode_actions(
        since=max_action + 1, device_id=config.gpodder_device,
    )
    if response.actions:
        datastore.append_actions(response.actions)
        logger.info(f"Added {len(response.actions)} actions")
    else:
        logger.info("No new actions")


def fetch_podcasts(config: SecretsConfig) -> None:
    client = PublicClient()
    podcasts = [client.get_podcast_data(url) for url in datastore.missing_podcasts()]
    if podcasts:
        datastore.append_podcasts(podcasts)
        logger.info(f"Added {len(podcasts)} podcasts")
    else:
        logger.info("No new podcasts")


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    config = SecretsConfig.instance()
    datastore.migrate_db()
    fetch_episode_actions(config)
    fetch_podcasts(config)
