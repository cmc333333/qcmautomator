import os
from typing import Iterable, Optional

from google.cloud.bigquery import Client
from google.cloud.bigquery.job import LoadJobConfig, QueryJobConfig
from mygpoclient.api import EpisodeAction

import sqlalchemy
from sqlalchemy import sql

_engine = sqlalchemy.create_engine(
    f"bigquery://{os.environ['GCP_PROJECT_ID']}/{os.environ['APP_NAME']}"
)
_meta = sqlalchemy.MetaData(bind=_engine)

episode_actions = sqlalchemy.Table(
    "episode_actions",
    _meta,
    sqlalchemy.Column("podcast", sqlalchemy.String(), nullable=False),
    sqlalchemy.Column("episode", sqlalchemy.String(), nullable=False),
    sqlalchemy.Column("action", sqlalchemy.String(), nullable=False),
    sqlalchemy.Column("device", sqlalchemy.String(), nullable=False),
    sqlalchemy.Column("timestamp", sqlalchemy.TIMESTAMP(timezone=True), nullable=False),
    sqlalchemy.Column("started", sqlalchemy.Integer),
    sqlalchemy.Column("position", sqlalchemy.Integer),
    sqlalchemy.Column("total", sqlalchemy.Integer),
)
episode_actions_stage = sqlalchemy.Table(
    "episode_actions_stage",
    _meta,
    sqlalchemy.Column("podcast", sqlalchemy.String(), nullable=False),
    sqlalchemy.Column("episode", sqlalchemy.String(), nullable=False),
    sqlalchemy.Column("action", sqlalchemy.String(), nullable=False),
    sqlalchemy.Column("device", sqlalchemy.String(), nullable=False),
    sqlalchemy.Column("timestamp", sqlalchemy.TIMESTAMP(timezone=True), nullable=False),
    sqlalchemy.Column("started", sqlalchemy.Integer),
    sqlalchemy.Column("position", sqlalchemy.Integer),
    sqlalchemy.Column("total", sqlalchemy.Integer),
)


def migrate_db():
    """Update the table schema to the latest. Naive solution for now."""
    _meta.create_all()


def max_action() -> Optional[int]:
    with _engine.connect() as conn:
        row = conn.execute(
            sql.select([sql.func.max(episode_actions.c.timestamp).label("max_ts")])
        ).fetchone()
        return int(row["max_ts"].timestamp()) if row else None


def append_actions(actions: Iterable[EpisodeAction]) -> None:
    client = Client()
    destination = client.get_table(
        f"{os.environ['GCP_PROJECT_ID']}"
        f".{os.environ['APP_NAME']}"
        ".episode_actions_stage"
    )
    load_job = client.load_table_from_json(
        destination=destination,
        json_rows=[
            {col.name: getattr(action, col.name) for col in episode_actions.columns}
            for action in actions
        ],
        job_config=LoadJobConfig(
            schema=destination.schema, write_disposition="WRITE_TRUNCATE"
        ),
    )
    load_job.result()  # wait for the job to finish

    merge_job = client.query(
        """
          MERGE INTO episode_actions target
          USING episode_actions_stage source
          ON (
            target.podcast = source.podcast
            AND target.episode = source.episode
            AND target.action = source.action
            AND target.device = source.device
            AND target.timestamp = source.timestamp
          )
          WHEN NOT MATCHED BY TARGET THEN
            INSERT ROW
        """,
        QueryJobConfig(
            default_dataset=f"{destination.project}.{destination.dataset_id}",
        ),
    )
    merge_job.result()
