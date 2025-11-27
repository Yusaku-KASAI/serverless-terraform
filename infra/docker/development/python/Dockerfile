FROM python:3.11

COPY ./serverless /build
RUN pip install --upgrade pip

RUN if [ -f /build/requirements.txt]; then pip install -r /build/requirements.txt; fi
RUN if [ -f /build/requirements-dev.txt]; then pip install -r /build/requirements-dev.txt; fi

RUN rm -rf /build

COPY ./serverless /serverless/

WORKDIR /serverless

ENTRYPOINT ["sleep", "infinity"]
