FROM python:3.8-slim

WORKDIR /app
RUN pip install pipenv==2018.11.26

COPY ["Pipfile", "Pipfile.lock", "./"]
RUN pipenv install --ignore-pipfile --system

COPY ["app.py", "datastore.py", "secrets_config.py", "./"]

ENV PYTHONUNBUFFERED=1

CMD exec gunicorn --bind 0.0.0.0:8080 --workers 1 --threads 8 --timeout 0 app:app 
