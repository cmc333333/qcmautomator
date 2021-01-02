import argparse
import dataclasses
from typing import Dict, Iterator, List, Optional

import google.auth
import pendulum
import requests
from defusedxml.ElementTree import fromstring as xml_from_str
from google.auth import impersonated_credentials
from google.cloud.logging_v2.client import Client
from tqdm import tqdm

from qcmautomator import config

SCOPES = ("https://www.googleapis.com/auth/logging.write",)


@dataclasses.dataclass
class Dates:
    event: pendulum.DateTime
    created: pendulum.DateTime
    read: Optional[pendulum.DateTime]

    def as_strs(self) -> Dict[str, Optional[str]]:
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


def logging_client(impersonate: Optional[str], project: Optional[str]) -> Client:
    credentials, user_project = google.auth.default(scopes=SCOPES)
    project = project or user_project
    if impersonate:
        credentials = impersonated_credentials.Credentials(
            credentials, target_principal=impersonate, target_scopes=SCOPES
        )
    return Client(credentials=credentials, project=project)


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


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--impersonate-service-account", nargs="?")
    parser.add_argument("--project", nargs="?")
    args = parser.parse_args()
    client = logging_client(args.impersonate_service_account, args.project)

    with client.logger("books").batch() as logger:
        for book in tqdm(get_books(config.goodreads_user_id())):
            as_dict = dataclasses.asdict(book)
            as_dict["dates"] = book.dates.as_strs()
            logger.log_struct(
                as_dict,
                insert_id=book.guid,
                timestamp=book.dates.event,
            )
