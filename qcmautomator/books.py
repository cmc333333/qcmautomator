import requests
import yaml
from defusedxml.ElementTree import fromstring as xml_from_str

from qcmautomator.auth import credentials


if __name__ == "__main__":
    with open("/etc/app/books.yml", "r") as secrets_file:
        secrets_config = yaml.safe_load(secrets_file)
    result = requests.get(
        f"https://www.goodreads.com/review/list_rss/{secrets_config['goodreads_user_id']}"
    )
    print(result.text)
