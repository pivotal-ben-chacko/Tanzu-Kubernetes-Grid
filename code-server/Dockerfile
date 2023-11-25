FROM ubuntu:jammy

RUN apt update && apt upgrade -y
RUN apt install curl -y
RUN mkdir /home/code-server
RUN curl -fsSL https://code-server.dev/install.sh | sh
