FROM python:3.9.1-slim as base
ENTRYPOINT [] # unset entrypoint from Python image
WORKDIR /usr/src/app
ENV PYTHONUNBUFFERED=1
RUN pip install pipenv==2020.11.15
COPY ["Pipfile", "Pipfile.lock", "./"]


FROM base AS production
RUN pipenv install --ignore-pipfile --system
COPY ["qcmautomator/*.py", "./qcmautomator/"]


FROM base AS development
RUN pipenv install --ignore-pipfile --system --dev
COPY --from=hashicorp/terraform:0.14.3 /bin/terraform /usr/bin/terraform
