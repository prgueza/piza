FROM postgres:14.5

RUN apt update && apt upgrade -y 
RUN apt-get -y install postgresql-14-cron

COPY * /docker-entrypoint-initdb.d/
RUN chmod +x /docker-entrypoint-initdb.d/*.sh

CMD ["-c", "cron.database_name=postgres"]