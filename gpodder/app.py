import logging
from time import time
from typing import List

from mygpoclient.api import MygPodderClient
from sqlalchemy.orm.session import Session as SessionType

import datastore
import parser
from secrets_config import SecretsConfig

logger = logging.getLogger("gpodder")


def update_episode_actions(session: SessionType, config: SecretsConfig) -> None:
    client = MygPodderClient(config.gpodder_username, config.gpodder_password)
    max_action = datastore.max_action(session) or time() - (60 * 60 * 24 * 45)
    hours = (time() - max_action) / 60 / 60
    logger.info(f"Fetching actions from the past {int(hours)} hours")
    response = client.download_episode_actions(
        since=max_action + 1, device_id=config.gpodder_device,
    )
    if response.actions:
        actions = [datastore.EpisodeAction.from_gpo(a) for a in response.actions]
        datastore.merge_data(datastore.EpisodeAction, actions)
        logger.info(f"Added {len(actions)} actions")
    else:
        logger.info("No new actions")


def backfill_podcasts(session: SessionType) -> None:
    podcasts: List[datastore.Podcast] = []
    for podcast_url in datastore.random_podcasts(session):
        podcast = parser.parse_podcast(podcast_url)
        if podcast:
            podcasts.append(podcast)
        else:
            logger.warning(f"Couldn't load podcast: {podcast_url}")
    datastore.merge_data(datastore.Podcast, podcasts)
    logger.info(f"Updated {len(podcasts)} podcasts")


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    config = SecretsConfig.instance()
    datastore.migrate_db()
    try:
        session = datastore.Session()
        update_episode_actions(session, config)
        backfill_podcasts(session)
    finally:
        session.close()
