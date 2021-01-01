import os
from typing import List

import google.auth
from google.auth.credentials import Credentials


def credentials(scopes: List[str]=None) -> Credentials:
    """Generates default GCP credentials with the provided scopes, optionally acting as
    a specific service account (defined by an env var)."""
    default_creds, _ = google.auth.default(scopes)
    if "SERVICE_ACCOUNT" in os.environ:
        return google.auth.impersonated_credentials.Credentials(
            default_creds, target_principle=os.environ["SERVICE_ACCOUNT"],
            target_scopes=scopes,
        )
    return default_creds
