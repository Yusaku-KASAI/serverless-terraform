# Dockerfile
FROM --platform=linux/amd64 python:3.11-slim

# 必要なパッケージをインストール(lessはoptional)
RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    default-libmysqlclient-dev \
    gcc \
    less \
    && apt-get clean

# Node.jsのインストール（Serverless Framework用）
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g serverless@3

# AWS CLIのインストール
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf aws awscliv2.zip

# Pythonパッケージの環境を整備
RUN pip install --upgrade pip

# 作業ディレクトリ
WORKDIR /serverless

COPY ./serverless /serverless/

RUN if [ -f package.json ]; then npm install; fi

# コンテナ内でのデフォルトコマンド
ENTRYPOINT  ["sleep", "infinity"]
