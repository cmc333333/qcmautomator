import logging
from typing import Iterator

import typer
from google.cloud.bigquery.job import LoadJobConfig
from google.cloud.bigquery.table import TableReference
from mygpoclient.api import EpisodeAction, MygPodderClient

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
    else:
        logger.info("No new actions")


cli = typer.Typer()
cli.command()(load_actions)
