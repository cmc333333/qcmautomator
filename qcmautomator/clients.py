import sys
from typing import Optional

import google.auth
from google.auth import impersonated_credentials
from google.cloud.bigquery.client import Client as BQClient
from trakt.client import TraktClient

from qcmautomator import config

BQ_SCOPES = ("https://www.googleapis.com/auth/bigquery",)
OOB = "urn:ietf:wg:oauth:2.0:oob"
REFRESH_TOKEN_PATH = config.CONFIG_DIR / "trakt_refresh_token"


def create_bq_client(impersonate: Optional[str], project: Optional[str]) -> BQClient:
    credentials, user_project = google.auth.default(scopes=BQ_SCOPES)
    project = project or user_project
    if impersonate:
        credentials = impersonated_credentials.Credentials(
            credentials, target_principal=impersonate, target_scopes=BQ_SCOPES
        )
    return BQClient(
        credentials=credentials, project=project, client_options={"scopes": BQ_SCOPES}
    )


def _manual_trakt_auth(client: TraktClient) -> None:
    if sys.stdin.isatty():
        print(f"Authorization URL: {client['oauth'].authorize_url(OOB)}")
        code = input("Code:")
        auth_info = client["oauth"].token(code, OOB)
        REFRESH_TOKEN_PATH.write_text(auth_info["refresh_token"])
    else:
        raise ValueError("Not a TTY. Can't proceed with Trakt Authorization")


def create_trakt_client() -> TraktClient:
    client = TraktClient()
    client.configuration.defaults.client(
        id=config.trakt_client_id(), secret=config.trakt_client_secret()
    )
    if not REFRESH_TOKEN_PATH.exists():
        _manual_trakt_auth(client)

    response = client["oauth"].token_refresh(REFRESH_TOKEN_PATH.read_text())
    client.configuration.defaults.oauth.from_response(response)
    REFRESH_TOKEN_PATH.write_text(
        client.configuration.defaults.data["oauth.refresh_token"]
    )
    return client
