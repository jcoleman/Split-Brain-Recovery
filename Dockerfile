FROM postgres:11

RUN apt-get update && apt-get install less sudo

ADD ./scripts/configure_postgres.sh /docker-entrypoint-initdb.d/configure_postgres.sh
ADD ./scripts/wait_for_psql.sh /
ADD ./scripts/postgres_runner.sh /

RUN mkdir /wal-investigation
ADD ./scripts/wal-investigation/* /wal-investigation/

RUN apt-get update && apt-get install -y ruby libpq5 libpq-dev ruby-dev build-essential
RUN gem install pg --no-ri --no-rdoc --source http://rubygems.org

RUN echo "export PS1='\$NODE_ROLE:\\w\\$ '" >> /etc/bash.bashrc

# Per Docker convention, the standard Postgres Dockerfile
# runs the postgres process as pid 0, and therefore you
# can't stop/start the server without stopping the container.
# The entrypoint file also gets in the way here, because it
# checks the command being run so that it can do cluster
# initialization and then launch postgres as an unprivileged
# user. We have to fake out that command name check (unless
# we want to copy the entrypoint file into this repo), so we
# get around this by naming our wrapper...postgres.
RUN ln -s /postgres_runner.sh /usr/bin/postgres

ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["postgres"]
