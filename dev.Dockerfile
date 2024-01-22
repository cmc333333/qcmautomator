FROM node:20.11-bookworm
WORKDIR /usr/src/app
COPY ["package-lock.json", "package.json", "/usr/src/app/"]
RUN ["npm", "install"]
USER "node"
