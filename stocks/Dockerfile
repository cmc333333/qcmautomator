FROM python:3.8-slim

WORKDIR /app
RUN pip install pipenv==2018.11.26

COPY ["Pipfile", "Pipfile.lock", "./"]
RUN pipenv install --ignore-pipfile --system

COPY ["app.py", "datastore.py", "secrets_config.py", "./"]

ENV PYTHONUNBUFFERED=1\
    GOOGLE_APPLICATION_CREDENTIALS=/app/creds.json

ENTRYPOINT ["python", "app.py"]
