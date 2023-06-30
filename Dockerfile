FROM golang:alpine3.18 as go-cron-builder

WORKDIR /home/go-cron

RUN <<EOF
apk add --no-cache bash wget unzip
wget --no-check-certificate -O /tmp/go-cron-src.zip https://github.com/Sorg666/go-cron/archive/refs/heads/master.zip
unzip /tmp/go-cron-src.zip -d /tmp
mv -v /tmp/go-cron-master/* /home/go-cron
rm -rf dist && mkdir -p dist && cd ./dist
go mod tidy
go build -o go-cron ../go-cron.go
EOF

FROM alpine:3.18

# permissions
ARG CONTAINER_UID=1000
ARG CONTAINER_GID=1000

# install dev tools
RUN <<EOF
export CONTAINER_USER=logrotate
export CONTAINER_GROUP=logrotate
addgroup -g $CONTAINER_GID logrotate
adduser -u $CONTAINER_UID -G logrotate -h /usr/bin/logrotate.d -s /bin/bash -S logrotate
apk add --no-cache bash tini tzdata logrotate
mkdir -p /usr/bin/logrotate.d
EOF

COPY --from=go-cron-builder /home/go-cron/dist /usr/bin

# environment variable for this container
ENV LOGROTATE_OLDDIR= \
    LOGROTATE_COMPRESSION= \
    LOGROTATE_INTERVAL= \
    LOGROTATE_COPIES= \
    LOGROTATE_SIZE= \
    LOGS_DIRECTORIES= \
    LOG_FILE_ENDINGS= \
    LOGROTATE_LOGFILE= \
    LOGROTATE_CRONSCHEDULE= \
    LOGROTATE_PARAMETERS= \
    LOGROTATE_STATUSFILE= \
    LOG_FILE=

COPY docker-entrypoint.sh /usr/bin/logrotate.d/docker-entrypoint.sh
COPY update-logrotate.sh /usr/bin/logrotate.d/update-logrotate.sh
COPY logrotate.sh /usr/bin/logrotate.d/logrotate.sh
COPY logrotateConf.sh /usr/bin/logrotate.d/logrotateConf.sh
COPY logrotateCreateConf.sh /usr/bin/logrotate.d/logrotateCreateConf.sh

ENTRYPOINT ["tini","--","/usr/bin/logrotate.d/docker-entrypoint.sh"]
VOLUME ["/logrotate-status"]
CMD ["cron"]
