import logging
import parser
from time import time
from typing import Iterable, List

from mygpoclient.api import MygPodderClient
from sqlalchemy.orm.session import Session as SessionType

import datastore
from secrets_config import SecretsConfig

logger = logging.getLogger("gpodder")


def update_episode_actions(
    session: SessionType, config: SecretsConfig
) -> List[datastore.EpisodeAction]:
    client = MygPodderClient(config.gpodder_username, config.gpodder_password)
    max_action = datastore.max_action(session) or time() - (60 * 60 * 24 * 45)
    hours = (time() - max_action) / 60 / 60
    logger.info(f"Fetching actions from the past {int(hours)} hours")
    response = client.download_episode_actions(
        since=max_action + 1, device_id=config.gpodder_device,
    )
    actions: List[datastore.EpisodeAction] = []
    if response.actions:
        actions = [datastore.EpisodeAction.from_gpo(a) for a in response.actions]
        datastore.merge_data(datastore.EpisodeAction, actions)
        logger.info(f"Added {len(actions)} actions")
    else:
        logger.info("No new actions")
    return actions


def populate_podcasts(session: SessionType, podcast_urls: Iterable[str]) -> None:
    """Fetch podcast RSS and merge in podcast + episodes."""
    podcasts: List[datastore.Podcast] = []
    episodes: List[datastore.Episode] = []
    for podcast_url in podcast_urls:
        podcast = parser.parse_podcast(podcast_url)
        if podcast:
            podcasts.append(podcast)
            episodes.extend(podcast.episodes)
        else:
            logger.warning(f"Couldn't load podcast: {podcast_url}")

    datastore.merge_data(datastore.Podcast, podcasts)
    logger.info(f"Updated {len(podcasts)} podcasts")

    datastore.merge_data(datastore.Episode, episodes)
    logger.info(f"Updated {len(episodes)} episodes")


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    config = SecretsConfig.instance()
    datastore.migrate_db()
    try:
        session = datastore.Session()
        actions = update_episode_actions(session, config)
        populate_podcasts(session, {a.podcast for a in actions})
        logger.info("Backfilling/refreshing up to ten podcasts.")
        populate_podcasts(session, datastore.random_podcasts(session))
    finally:
        session.close()
