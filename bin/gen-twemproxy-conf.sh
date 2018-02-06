#!/usr/bin/env bash

REDIS_URLS=${TWEMPROXY_URLS:-REDISCLOUD_URL}
n=1

rm -f /app/vendor/twemproxy/twemproxy.yml

for _REDIS_URL in $REDIS_URLS
do
  echo "Setting ${_REDIS_URL}_TWEMPROXY config var"
  eval REDIS_URL_VALUE=\$$_REDIS_URL

  # redis://rediscloud:UV0d4ikbK7UIegq5@pub-redis-19886.us-east-1-1.2.ec2.garantiadata.com:19886
  DB=$(echo ${REDIS_URL_VALUE} | perl -lne 'print "$1 $2 $3 $4 $5 $6" if /^redis(?:ql)?:\/\/([^:]+):([^@]+)@(.*?):(.*?)(\\?.*)?$/')
  DB_URI=( $DB )
  DB_USER=${DB_URI[0]}
  DB_PASS=${DB_URI[1]}
  DB_HOST=${DB_URI[2]}
  DB_PORT=${DB_URI[3]}

  i=0

  export TWEMPROXY_CONFIG_GENERATED="1"

  while [ $i -lt 16 ]; do
    port=""

    if [ $i -lt 10 ]; then
      port="62${n}0${i}"
    else
      port="62${n}${i}"
    fi

    NEW_URL=redis://${DB_USER}:${DB_PASS}@127.0.0.1:${port}
    export ${_REDIS_URL}_${i}_TWEMPROXY=${NEW_URL}
    export ${_REDIS_URL}_${i}_UNPROXIED=${REDIS_URL_VALUE}
    echo "Pointing to ${DB_HOST}:${DB_PORT}"

    cat >> /app/vendor/twemproxy/twemproxy.yml << EOFEOF
${_REDIS_URL}_${i}:
  listen: 127.0.0.1:${port}
  redis: true
  redis_auth: ${DB_PASS}
  redis_db: ${i}
  servers:
   - ${DB_HOST}:${DB_PORT}:1
  timeout: 5000
EOFEOF

    let "i += 1"
  done


  let "n += 1"
done

chmod go-rwx /app/vendor/twemproxy/*
