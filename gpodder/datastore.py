import os
from typing import Iterable, Optional

from google.cloud.bigquery import Client
from google.cloud.bigquery.job import LoadJobConfig, QueryJobConfig
from mygpoclient.api import EpisodeAction
from mygpoclient.public import Episode
from mygpoclient.simple import Podcast

import sqlalchemy
from sqlalchemy import sql

_engine = sqlalchemy.create_engine(
    f"bigquery://{os.environ['GCP_PROJECT_ID']}/{os.environ['APP_NAME']}"
)
_meta = sqlalchemy.MetaData(bind=_engine)

episode_actions = sqlalchemy.Table(
    "episode_actions",
    _meta,
    sqlalchemy.Column("podcast", sqlalchemy.String(), nullable=False, primary_key=True),
    sqlalchemy.Column("episode", sqlalchemy.String(), nullable=False, primary_key=True),
    sqlalchemy.Column("action", sqlalchemy.String(), nullable=False, primary_key=True),
    sqlalchemy.Column("device", sqlalchemy.String(), nullable=False, primary_key=True),
    sqlalchemy.Column(
        "timestamp",
        sqlalchemy.TIMESTAMP(timezone=True),
        nullable=False,
        primary_key=True,
    ),
    sqlalchemy.Column("started", sqlalchemy.Integer),
    sqlalchemy.Column("position", sqlalchemy.Integer),
    sqlalchemy.Column("total", sqlalchemy.Integer),
)
episode_actions_stage = sqlalchemy.Table(
    "episode_actions_stage", _meta, *(col.copy() for col in episode_actions.columns)
)

podcasts = sqlalchemy.Table(
    "podcasts",
    _meta,
    sqlalchemy.Column("podcast", sqlalchemy.String(), primary_key=True, nullable=False),
    sqlalchemy.Column("title", sqlalchemy.String(), nullable=False),
    sqlalchemy.Column("description", sqlalchemy.String()),
    sqlalchemy.Column("website", sqlalchemy.String()),
    sqlalchemy.Column("logo", sqlalchemy.String()),
)
podcasts_stage = sqlalchemy.Table(
    "podcasts_stage", _meta, *(col.copy() for col in podcasts.columns)
)

episodes = sqlalchemy.Table(
    "episodes",
    _meta,
    sqlalchemy.Column("episode", sqlalchemy.String(), nullable=False, primary_key=True),
    sqlalchemy.Column("podcast", sqlalchemy.String(), nullable=False),
    sqlalchemy.Column("title", sqlalchemy.String(), nullable=False),
    sqlalchemy.Column("description", sqlalchemy.String()),
    sqlalchemy.Column("website", sqlalchemy.String()),
    sqlalchemy.Column(
        "released_at", sqlalchemy.TIMESTAMP(timezone=True), nullable=False
    ),
)
episodes_stage = sqlalchemy.Table(
    "episodes_stage", _meta, *(col.copy() for col in episodes.columns)
)


def migrate_db():
    """Update the table schema to the latest. Naive solution for now."""
    _meta.create_all()


def max_action() -> Optional[int]:
    with _engine.connect() as conn:
        row = conn.execute(
            sql.select([sql.func.max(episode_actions.c.timestamp)])
        ).fetchone()
        return int(row[0].timestamp()) if row[0] else None


def missing_podcasts(limit: int = 10) -> Iterable[str]:
    with _engine.connect() as conn:
        rows = conn.execute(
            sql.select(distinct=True, limit=limit, columns=[episode_actions.c.podcast])
            .select_from(
                episode_actions.outerjoin(
                    podcasts, episode_actions.c.podcast == podcasts.c.podcast,
                )
            )
            .where(podcasts.c.podcast.is_(None))
        ).fetchall()
        for row in rows:
            yield row[0]


def merge_data(target_sql_tbl: sqlalchemy.Table, data: Iterable[dict]) -> None:
    """Generic function to merge a chunk of data into a target table, removing any
    duplicates."""
    client = Client()
    stage_bq_tbl = client.get_table(
        f"{_engine.dialect.dataset_id}.{target_sql_tbl.name}_stage"
    )
    load_job = client.load_table_from_json(
        destination=stage_bq_tbl,
        json_rows=data,
        job_config=LoadJobConfig(
            schema=stage_bq_tbl.schema, write_disposition="WRITE_TRUNCATE"
        ),
    )
    load_job.result()  # wait for the job to finish

    merge_text = " AND ".join(
        [
            f"target.{col.name} = source.{col.name}"
            for col in target_sql_tbl.columns
            if col.primary_key
        ]
    )
    merge_job = client.query(
        f"""
          MERGE INTO {target_sql_tbl.name} target
          USING {stage_bq_tbl.table_id} source
          ON ({merge_text})
          WHEN NOT MATCHED BY TARGET THEN
            INSERT ROW
        """,
        QueryJobConfig(
            default_dataset=(
                f"{os.environ['GCP_PROJECT_ID']}.{_engine.dialect.dataset_id}"
            ),
        ),
    )
    merge_job.result()


def append_actions(actions: Iterable[EpisodeAction]) -> None:
    merge_data(
        episode_actions,
        [
            {col.name: getattr(action, col.name) for col in episode_actions.columns}
            for action in actions
        ],
    )


def append_podcasts(gpo_podcasts: Iterable[Podcast]) -> None:
    merge_data(
        podcasts,
        [
            {
                "podcast": podcast.url,
                "title": podcast.title,
                "description": podcast.description or None,
                "website": podcast.website,
                "logo": podcast.logo_url,
            }
            for podcast in gpo_podcasts
        ],
    )


def append_episodes(gpo_episodes: Iterable[Episode]) -> None:
    merge_data(
        episodes,
        [
            {
                "episode": episode.url,
                "podcast": episode.podcast_url,
                "title": episode.title,
                "description": episode.description or None,
                "website": episode.website,
                "released_at": episode.released,
            }
            for episode in gpo_episodes
        ],
    )
