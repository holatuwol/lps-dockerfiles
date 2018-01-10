FROM mysql:5.7

ADD runtime.cnf /etc/mysql/conf.d/
ADD init.sql /docker-entrypoint-initdb.d/

ENV MYSQL_ALLOW_EMPTY_PASSWORD yes
ENV MYSQL_USER lportal
ENV MYSQL_PASSWORD lportal

EXPOSE 3306