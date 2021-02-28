import logging
from typing import Any, Callable, Dict, Iterable

import pendulum
import typer
from google.cloud.bigquery.job import CopyJobConfig, LoadJobConfig
from google.cloud.bigquery.table import TableReference

from qcmautomator.clients import create_bq_client, create_trakt_client

DataRows = Iterable[Dict[str, Any]]
logger = logging.getLogger(__name__)


def fetch_episodes() -> DataRows:
    results = create_trakt_client()["users/*/history"].episodes(
        "me", extended="full", pagination=True, per_page=1000
    )
    for episode in results:
        as_dict = episode.to_dict()
        as_dict["watched_at"] = episode.watched_at.isoformat()
        as_dict["season"] = episode.season.pk
        # Work around a little bug
        episode.show.seasons = {}
        as_dict["show"] = episode.show.to_dict()
        yield as_dict


def fetch_movies() -> DataRows:
    results = create_trakt_client()["users/*/history"].movies(
        "me", extended="full", pagination=True, per_page=1000
    )
    for movie in results:
        as_dict = movie.to_dict()
        as_dict["watched_at"] = movie.watched_at.isoformat()
        yield as_dict


def load_data(
    video_type: str,
    data_fn: Callable[[], DataRows],
    project: str = None,
    impersonate_service_account: str = None,
) -> None:
    bq_client = create_bq_client(impersonate_service_account, project)
    now = int(pendulum.now().timestamp())
    perm_table = TableReference.from_string(
        f"{bq_client.project}.watching.{video_type}"
    )
    tmp_table = TableReference.from_string(
        f"{bq_client.project}.watching_loading.{video_type}_{now}"
    )
    rows = list(data_fn())
    logger.info(f"Loading {len(rows)} {video_type}s")
    bq_client.load_table_from_json(
        rows, tmp_table, job_config=LoadJobConfig(autodetect=True)
    ).result()
    bq_client.copy_table(
        tmp_table,
        perm_table,
        job_config=CopyJobConfig(write_disposition="WRITE_TRUNCATE"),
    ).result()


def load_episodes(project: str = None, impersonate_service_account: str = None) -> None:
    return load_data("episodes", fetch_episodes, project, impersonate_service_account)


def load_movies(project: str = None, impersonate_service_account: str = None) -> None:
    return load_data("movies", fetch_movies, project, impersonate_service_account)


cli = typer.Typer()
cli.command()(load_episodes)
cli.command()(load_movies)
