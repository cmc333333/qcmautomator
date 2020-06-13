from typing import Optional

import feedparser
import pendulum

from datastore import Episode, Podcast


def parse_podcast(url: str) -> Optional[Podcast]:
    """Fetch data from the podcast's RSS and return it (if possible) packaged as a
    GPodder "Podcast"."""
    parsed = feedparser.parse(url)
    if parsed.feed and parsed.feed.get("title"):
        entries = [
            entry for entry in parsed.entries
            if any(link.rel == "enclosure" for link in entry.links)
        ]
        podcast = Podcast(
            podcast=url,
            title=parsed.feed.title,
            description=parsed.feed.get("summary"),
            website=parsed.feed.get("link"),
            logo=parsed.feed.image.href,
        )
        podcast.episodes = [
            Episode(
                episode=next(link for link in ep.links if link.rel == "enclosure").href,
                podcast=url,
                title=ep.title,
                description=ep.get("summary"),
                released_at=pendulum.parse(ep.published, strict=False),
                logo=ep.image.href if "image" in ep else None,
            )
            for ep in entries
        ]
        return podcast
    return None
