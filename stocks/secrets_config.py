import dataclasses
import os
from typing import ClassVar, Optional

from google.cloud import secretmanager_v1
from yaml import safe_load


@dataclasses.dataclass
class SecretsConfig:
    alpha_vantage_key: str

    _instance: ClassVar[Optional["SecretsConfig"]] = None

    @classmethod
    def instance(cls) -> "SecretsConfig":
        if cls._instance is None:
            client = secretmanager_v1.SecretManagerServiceClient()
            name = client.secret_version_path(
                os.environ["GCP_PROJECT_ID"], os.environ["APP_NAME"], "latest",
            )
            response = client.access_secret_version(name)
            as_dict = safe_load(response.payload.data)
            cls._instance = cls(**as_dict)
        return cls._instance
