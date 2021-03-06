import dataclasses
import logging
from typing import Any, Dict, Iterator, List, Optional

import pendulum
import requests
import typer
from defusedxml.ElementTree import fromstring as xml_from_str
from google.cloud.bigquery.job import LoadJobConfig
from google.cloud.bigquery.table import TableReference

from qcmautomator import config
from qcmautomator.clients import create_bq_client

logger = logging.getLogger(__name__)


@dataclasses.dataclass
class Dates:
    event: pendulum.DateTime
    created: pendulum.DateTime
    read: Optional[pendulum.DateTime]

    def simple_dict(self) -> Dict[str, Optional[str]]:
        return {
            "event": self.event.isoformat(),
            "created": self.created.isoformat(),
            "read": self.read and self.read.isoformat(),
        }


@dataclasses.dataclass
class Images:
    default: str
    small: str
    medium: str
    large: str


@dataclasses.dataclass
class Book:
    author_name: str
    book_id: int
    dates: Dates
    description: str
    guid: str
    images: Images
    isbn: str
    link: str
    num_pages: Optional[int]
    publish_year: Optional[int]
    title: str
    user_shelves: List[str]

    def simple_dict(self) -> Dict[str, Any]:
        result = dataclasses.asdict(self)
        result["dates"] = self.dates.simple_dict()
        return result


def get_books(goodreads_user_id: int) -> Iterator[Book]:
    url = f"https://www.goodreads.com/review/list_rss/{goodreads_user_id}"
    result = requests.get(url)
    as_xml = xml_from_str(result.text)
    for xml_item in as_xml.findall(".//item"):
        num_pages = xml_item.findtext("./book/num_pages")
        publish_year = xml_item.findtext("book_published")
        read_at = xml_item.findtext("user_read_at")
        user_shelves = xml_item.findtext("user_shelves")
        yield Book(
            author_name=xml_item.findtext("author_name"),
            book_id=int(xml_item.findtext("book_id")),
            dates=Dates(
                event=pendulum.parse(xml_item.findtext("pubDate"), strict=False),
                created=pendulum.parse(
                    xml_item.findtext("user_date_created"), strict=False
                ),
                read=pendulum.parse(read_at, strict=False) if read_at else None,
            ),
            description=xml_item.findtext("book_description"),
            guid=xml_item.findtext("guid"),
            images=Images(
                default=xml_item.findtext("book_image_url"),
                small=xml_item.findtext("book_small_image_url"),
                medium=xml_item.findtext("book_medium_image_url"),
                large=xml_item.findtext("book_large_image_url"),
            ),
            isbn=xml_item.findtext("isbn"),
            link=xml_item.findtext("link"),
            num_pages=int(num_pages) if num_pages else None,
            publish_year=int(publish_year) if publish_year else None,
            title=xml_item.findtext("title"),
            user_shelves=user_shelves.split(",") if user_shelves else [],
        )


def load_data(project: str = None, impersonate_service_account: str = None) -> None:
    client = create_bq_client(impersonate_service_account, project)
    now = int(pendulum.now().timestamp())
    tmp_table = TableReference.from_string(
        f"{client.project}.books_loading.as_of_{now}"
    )
    rows = [b.simple_dict() for b in get_books(config.goodreads_user_id())]
    logger.info(f"Writing {len(rows)} books")
    client.load_table_from_json(
        rows,
        tmp_table,
        job_config=LoadJobConfig(autodetect=True),
    ).result()
    logger.info("Merging books")
    client.query(
        f"""
        MERGE INTO `{client.project}.books.books` dst
        USING `{client.project}.books_loading.{tmp_table.table_id}` src
        ON src.guid = dst.guid
        WHEN MATCHED THEN UPDATE
          SET {', '.join(f'{f.name}=src.{f.name}' for f in dataclasses.fields(Book))}
        WHEN NOT MATCHED
          THEN INSERT({', '.join(f.name for f in dataclasses.fields(Book))})
          VALUES({', '.join(f'src.{f.name}' for f in dataclasses.fields(Book))})
        """
    ).result()


cli = typer.Typer()
cli.command()(load_data)
