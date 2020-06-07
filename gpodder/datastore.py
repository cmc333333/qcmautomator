import os
from typing import Iterable, Optional, Union

import sqlalchemy
from google.cloud.bigquery import Client
from google.cloud.bigquery.job import LoadJobConfig, QueryJobConfig
from mygpoclient.api import EpisodeAction as GPOEpisodeAction
from sqlalchemy import sql
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship, sessionmaker
from sqlalchemy.orm.session import Session as SessionType

_engine = sqlalchemy.create_engine(
    f"bigquery://{os.environ['GCP_PROJECT_ID']}/{os.environ['APP_NAME']}"
)
Session = sessionmaker(bind=_engine)
Base = declarative_base()


class EpisodeActionBase:
    podcast = sqlalchemy.Column(sqlalchemy.String(), nullable=False, primary_key=True)
    episode = sqlalchemy.Column(sqlalchemy.String(), nullable=False, primary_key=True)
    action = sqlalchemy.Column(sqlalchemy.String(), nullable=False, primary_key=True)
    device = sqlalchemy.Column(sqlalchemy.String(), nullable=False, primary_key=True)
    timestamp = sqlalchemy.Column(
        sqlalchemy.TIMESTAMP(timezone=True), nullable=False, primary_key=True,
    )
    started = sqlalchemy.Column(sqlalchemy.Integer)
    position = sqlalchemy.Column(sqlalchemy.Integer)
    total = sqlalchemy.Column(sqlalchemy.Integer)


class EpisodeAction(EpisodeActionBase, Base):
    __tablename__ = "episode_actions"

    @classmethod
    def from_gpo(cls, action: GPOEpisodeAction) -> "EpisodeAction":
        return cls(
            podcast=action.podcast,
            episode=action.episode,
            action=action.action,
            device=action.device,
            timestamp=action.timestamp,
            started=action.started,
            position=action.position,
            total=action.total,
        )

    def to_bq_dict(self) -> dict:
        result = {col.name: getattr(self, col.name) for col in self.__table__.columns}
        result["timestamp"] = self.timestamp.isoformat(sep=" ")
        return result


class EpisodeActionStage(EpisodeActionBase, Base):
    __tablename__ = "episode_actions_stage"


class PodcastBase:
    podcast = sqlalchemy.Column(sqlalchemy.String(), primary_key=True, nullable=False)
    title = sqlalchemy.Column(sqlalchemy.String(), nullable=False)
    description = sqlalchemy.Column(sqlalchemy.String())
    website = sqlalchemy.Column(sqlalchemy.String())
    logo = sqlalchemy.Column(sqlalchemy.String())


class Podcast(PodcastBase, Base):
    __tablename__ = "podcasts"

    episodes = relationship("Episode", uselist=True)

    def to_bq_dict(self) -> dict:
        return {col.name: getattr(self, col.name) for col in self.__table__.columns}


class PodcastStage(PodcastBase, Base):
    __tablename__ = "podcasts_stage"


class EpisodeBase:
    episode = sqlalchemy.Column(sqlalchemy.String(), primary_key=True, nullable=False)
    title = sqlalchemy.Column(sqlalchemy.String(), nullable=False)
    description = sqlalchemy.Column(sqlalchemy.String())
    released_at = sqlalchemy.Column(sqlalchemy.TIMESTAMP(timezone=True), nullable=False)
    logo = sqlalchemy.Column(sqlalchemy.String())


class Episode(EpisodeBase, Base):
    __tablename__ = "episodes"
    podcast = sqlalchemy.Column(
        sqlalchemy.String(), sqlalchemy.ForeignKey("podcasts.podcast"), nullable=False
    )

    def to_bq_dict(self) -> dict:
        result = {col.name: getattr(self, col.name) for col in self.__table__.columns}
        result["released_at"] = self.released_at.isoformat(sep=" ")
        return result


class EpisodeStage(EpisodeBase, Base):
    __tablename__ = "episodes_stage"
    podcast = sqlalchemy.Column(
        sqlalchemy.String(), sqlalchemy.ForeignKey("podcasts.podcast"), nullable=False
    )


def migrate_db():
    """Update the table schema to the latest. Naive solution for now."""
    Base.metadata.create_all(_engine)


def max_action(session: SessionType) -> Optional[int]:
    max_ts = session.scalar(sql.func.max(EpisodeAction.timestamp))
    return max_ts and int(max_ts.timestamp())


def random_podcasts(session: SessionType, limit: int = 10) -> Iterable[str]:
    rows = (
        session.query(EpisodeAction.podcast)
        .group_by(EpisodeAction.podcast)
        .order_by(sql.func.rand())
        .limit(limit)
        .all()
    )
    for row in rows:
        yield row[0]


def merge_data(
    target_cls, data: Iterable[Union[Episode, EpisodeAction, Podcast]]
) -> None:
    """Generic function to merge a chunk of data into a target table, removing any
    duplicates."""
    client = Client()
    stage_bq = client.get_table(
        f"{os.environ['APP_NAME']}.{target_cls.__tablename__}_stage"
    )

    load_job = client.load_table_from_json(
        destination=stage_bq,
        json_rows=[elt.to_bq_dict() for elt in data],
        job_config=LoadJobConfig(
            schema=stage_bq.schema, write_disposition="WRITE_TRUNCATE"
        ),
    )
    load_job.result()  # wait for the job to finish

    on_text = " AND ".join(
        [
            f"target.{col.name} = source.{col.name}"
            for col in target_cls.__table__.columns
            if col.primary_key
        ]
    )
    set_text = ", ".join(
        [
            f"target.{col.name} = source.{col.name}"
            for col in target_cls.__table__.columns
            if not col.primary_key
        ]
    )
    merge_job = client.query(
        f"""
          MERGE INTO {target_cls.__tablename__} target
          USING {stage_bq.table_id} source
          ON ({on_text})
          WHEN MATCHED THEN
            UPDATE SET {set_text}
          WHEN NOT MATCHED BY TARGET THEN
            INSERT ROW
        """,
        QueryJobConfig(
            default_dataset=(
                f"{os.environ['GCP_PROJECT_ID']}.{os.environ['APP_NAME']}"
            ),
        ),
    )
    merge_job.result()
