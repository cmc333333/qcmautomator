FROM node:20.11-bookworm

RUN ["npm", "install", "--global", "prettier@3.2.4"]

WORKDIR /usr/src/terraform
ENV TF_DATA_DIR=/usr/src/terraform/.terraform/
COPY ["terraform/.terraform-version", "."]
RUN \
  wget https://releases.hashicorp.com/terraform/$(cat /usr/src/terraform/.terraform-version)/terraform_$(cat /usr/src/terraform/.terraform-version)_linux_$(dpkg --print-architecture).zip -O /tmp/terraform.zip \
  && cd /tmp \
  && unzip terraform.zip \
  && rm terraform.zip \
  && mv terraform /usr/local/bin/terraform
COPY ["terraform/", "."]
RUN \
  mkdir -p $TF_DATA_DIR \
  && terraform init -reconfigure -backend=false \
  && chmod a+r -R $TF_DATA_DIR \
  && chmod a+w -R $TF_DATA_DIR

USER "node"
