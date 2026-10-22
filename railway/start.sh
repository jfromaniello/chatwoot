#!/bin/sh

set -e

echo Waiting for database...

while ! pg_isready -h ${PGHOST} -p ${PGPORT}; do sleep 0.25; done;

echo Database is now available

bundle exec rails db:chatwoot_prepare

bundle exec rails db:migrate

# CHATWOOT_SIDEKIQ_ENABLED=false levanta solo Rails: sirve para un entorno de
# prueba contra una copia de la base sin que Sidekiq mande mails ni llame a APIs
# externas, o para pausar Sidekiq sin bajar la web.
if [ "${CHATWOOT_SIDEKIQ_ENABLED:-true}" = "false" ]; then
  exec bundle exec rails s -b 0.0.0.0 -p $PORT
fi

multirun \
    "bundle exec sidekiq -C config/sidekiq.yml" \
    "bundle exec rails s -b 0.0.0.0 -p $PORT"

false
