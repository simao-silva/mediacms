ARG PYTHON_VERSION

############ BENTO COMPILATION ############
FROM python:${PYTHON_VERSION}-alpine AS bento-compiler

# LABEL source_code=https://github.com/axiomatic-systems/Bento4

# Setup environment variables
ARG BENTO4_VERSION

# Install Dependencies
RUN apk update && \
    apk add --no-cache ca-certificates bash make cmake gcc g++ git

# Copy Sources and build
RUN set -eux && \
    ARCH=$(uname --m) && \
    if [ $(uname --m) = "aarch64" ]; then ARCH="arm"; fi && \
    git clone https://github.com/axiomatic-systems/Bento4 -b ${BENTO4_VERSION} /tmp/bento4 && \
    rm -rf /tmp/bento4/cmakebuild && \
    mkdir -p /tmp/bento4/cmakebuild/${ARCH} && \
    cd /tmp/bento4/cmakebuild/${ARCH} && \
    cmake -DCMAKE_BUILD_TYPE=Release ../.. && \
    make

# Install
RUN set -eux && \
    ARCH=$(uname --m) && \
    if [ $(uname --m) = "aarch64" ]; then ARCH="arm"; fi && \
    cd /tmp/bento4 && \
    python3 Scripts/SdkPackager.py ${ARCH} . cmake && \
    mkdir /opt/bento4 && \
    mv /tmp/bento4/SDK/Bento4-SDK-*/* /opt/bento4


############ OTHER COMPILATION ############
FROM python:${PYTHON_VERSION}-slim-buster AS compile-image

SHELL ["/bin/bash", "-c"]

# Set up virtualenv
ENV VIRTUAL_ENV=/home/mediacms.io
ENV PATH="$VIRTUAL_ENV/bin:$PATH"
ENV PIP_NO_CACHE_DIR=1

RUN apt-get update && \
    apt-get install --no-install-recommends -y gcc libc6-dev libpq-dev

RUN set -eux && \
    mkdir -p /home/mediacms.io/mediacms/logs && \
    cd /home/mediacms.io && \ 
    python3 -m venv "$VIRTUAL_ENV"

# Install dependencies:
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . /home/mediacms.io/mediacms
WORKDIR /home/mediacms.io/mediacms

COPY --from=bento-compiler /opt/bento4 ../bento4


############ RUNTIME IMAGE ############
FROM python:${PYTHON_VERSION}-slim-buster as runtime-image

ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV ADMIN_USER='admin'
ENV ADMIN_PASSWORD='mediacms'
ENV ADMIN_EMAIL='admin@localhost'

# See: https://github.com/celery/celery/issues/6285#issuecomment-715316219
ENV CELERY_APP='cms'

# Use these to toggle which processes supervisord should run
ENV ENABLE_UWSGI='yes'
ENV ENABLE_NGINX='yes'
ENV ENABLE_CELERY_BEAT='yes'
ENV ENABLE_CELERY_SHORT='yes'
ENV ENABLE_CELERY_LONG='yes'
ENV ENABLE_MIGRATIONS='yes'

# Set up virtualenv
ENV VIRTUAL_ENV=/home/mediacms.io
ENV PATH="$VIRTUAL_ENV/bin:$PATH"

COPY --chown=www-data:www-data --from=compile-image /home/mediacms.io /home/mediacms.io

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        supervisor nginx ffmpeg imagemagick procps libpq-dev && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get purge --auto-remove -y && \
    apt-get clean

WORKDIR /home/mediacms.io/mediacms

EXPOSE 9000 80

RUN chmod +x ./deploy/docker/entrypoint.sh

ENTRYPOINT ["./deploy/docker/entrypoint.sh"]

CMD ["./deploy/docker/start.sh"]
