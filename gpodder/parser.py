from typing import Optional

import feedparser

from datastore import Podcast


def parse_podcast(url: str) -> Optional[Podcast]:
    """Fetch data from the podcast's RSS and return it (if possible) packaged as a
    GPodder "Podcast"."""
    parsed = feedparser.parse(url)
    if parsed.feed and parsed.feed.get("title"):
        return Podcast(
            podcast=url,
            title=parsed.feed.title,
            description=parsed.feed.get("summary"),
            website=parsed.feed.link,
            logo=parsed.feed.image.href,
        )
    return None
