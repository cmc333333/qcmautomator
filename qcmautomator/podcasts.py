import logging
from typing import Dict, Iterator, List, Optional, Set, Tuple
from urllib.error import URLError

import feedparser
import pendulum
import typer
from google.cloud.bigquery.client import Client as BQClient
from google.cloud.bigquery.job import LoadJobConfig
from google.cloud.bigquery.table import TableReference
from mygpoclient.api import EpisodeAction, MygPodderClient
from mygpoclient.public import Episode
from mygpoclient.simple import Podcast
from tqdm import tqdm

from qcmautomator import config
from qcmautomator.clients import create_bq_client

logger = logging.getLogger(__name__)


def get_podcasts(since: int) -> Iterator[EpisodeAction]:
    client = MygPodderClient(
        config.gpodder_username(), config.gpodder_password(), config.gpodder_host()
    )
    response = client.download_episode_actions(since=since)
    yield from response.actions


def load_actions(project: str = None, impersonate_service_account: str = None) -> None:
    bq_client = create_bq_client(impersonate_service_account, project)
    table = TableReference.from_string(f"{bq_client.project}.podcasts.episode_actions")
    start_at = list(
        bq_client.query(
            f"""
            SELECT UNIX_SECONDS(MAX(timestamp)) + 1
            FROM `{table.dataset_id}.{table.table_id}`
            """
        )
    )[0][0]
    data = [p.__dict__ for p in get_podcasts(start_at)]
    if data:
        logger.info(f"Appending {len(data)} actions")
        bq_client.load_table_from_json(
            data,
            table,
            job_config=LoadJobConfig(autodetect=True),
        ).result()
        load_podcasts(bq_client, {d["podcast"] for d in data})
    else:
        logger.info("No new actions")


def parse_podcast(url: str) -> Optional[Tuple[Podcast, List[Episode]]]:
    """Fetch data from the podcast's RSS and return it (if possible) packaged as a
    GPodder "Podcast"."""
    logger.debug(f"Parsing {url}")
    try:
        parsed = feedparser.parse(url)
    except URLError:
        logger.exception(f"Problem fetching {url}")
        return None

    if parsed.feed and parsed.feed.get("title"):
        podcast = Podcast(
            url=url,
            title=parsed.feed.title,
            description=parsed.feed.get("summary"),
            website=parsed.feed.get("link"),
            subscribers=None,
            subscribers_last_week=None,
            mygpo_link=None,
            logo_url=parsed.feed.image.href,
        )
        episodes = [
            Episode(
                title=ep.title,
                url=next(link for link in ep.links if link.rel == "enclosure").href,
                podcast_title=podcast.title,
                podcast_url=podcast.url,
                description=ep.get("summary"),
                website=podcast.website,
                released=pendulum.parse(ep.published, strict=False),
                # Misuse this field
                mygpo_link=ep.image.href if "image" in ep else None,
            )
            for ep in parsed.entries
            if any(link.rel == "enclosure" for link in ep.links)
        ]
        return (podcast, episodes)
    logger.warn(f"Missing a feed/title: {url}")
    return None


def load_podcasts(client: BQClient, urls: Set[str]) -> None:
    now = int(pendulum.now().timestamp())
    tmp_episodes = TableReference.from_string(
        f"{client.project}.podcasts_loading.episodes_{now}"
    )
    tmp_podcasts = TableReference.from_string(
        f"{client.project}.podcasts_loading.podcasts_{now}"
    )
    episodes: Dict[str, Episode] = {}
    podcasts: List[Podcast] = []
    pbar = tqdm(urls)
    for url in pbar:
        pbar.set_description(url)
        parsed = parse_podcast(url)
        if parsed:
            podcasts.append(parsed[0])
            episodes.update({e.url:e for e in parsed[1]})

    if podcasts:
        logger.info(f"Writing {len(podcasts)} podcasts")
        client.load_table_from_json(
            [
                {
                    "description": p.description,
                    "logo_url": p.logo_url,
                    "title": p.title,
                    "url": p.url,
                    "website": p.website,
                }
                for p in podcasts
            ],
            tmp_podcasts,
            job_config=LoadJobConfig(autodetect=True),
        ).result()
        client.query(
            f"""
            MERGE INTO `{client.project}.podcasts.podcasts` dst
            USING `{client.project}.podcasts_loading.{tmp_podcasts.table_id}` src
            ON src.url = dst.url
            WHEN MATCHED THEN UPDATE
              SET description=src.description,
              logo_url=src.logo_url,
              title=src.title,
              website=src.website
            WHEN NOT MATCHED THEN INSERT(description, logo_url, title, url, website)
              VALUES(src.description, src.logo_url, src.title, src.url, src.website)
            """
        ).result()
    else:
        logger.warn("No podcasts parsed")

    if episodes:
        logger.info(f"Writing {len(episodes)} episodes")
        client.load_table_from_json(
            [
                {
                    "description": e.description,
                    "logo_url": e.mygpo_link,
                    "podcast": e.podcast_url,
                    "released": e.released.isoformat(),
                    "title": e.title,
                    "url": e.url,
                }
                for e in episodes.values()
            ],
            tmp_episodes,
            job_config=LoadJobConfig(autodetect=True),
        ).result()

        client.query(
            f"""
            MERGE INTO `{client.project}.podcasts.episodes` dst
            USING `{client.project}.podcasts_loading.{tmp_episodes.table_id}` src
            ON src.url = dst.url
            WHEN MATCHED THEN UPDATE
              SET description=src.description,
              logo_url=src.logo_url,
              podcast=src.podcast,
              released=src.released,
              title=src.title
            WHEN NOT MATCHED
              THEN INSERT(description, logo_url, podcast, released, title, url)
              VALUES(
                src.description, src.logo_url, src.podcast, src.released,
                src.title, src.url
              )
            """
        ).result()
    else:
        logger.warn("No episodes parsed")


def load_all_podcasts(
    project: str = None, impersonate_service_account: str = None
) -> None:
    bq_client = create_bq_client(impersonate_service_account, project)
    results = bq_client.query(
        f"""
        SELECT DISTINCT podcast
        FROM {bq_client.project}.podcasts.episode_actions
        """
    )
    load_podcasts(bq_client, {row[0] for row in results})


cli = typer.Typer()
cli.command()(load_actions)
cli.command()(load_all_podcasts)
