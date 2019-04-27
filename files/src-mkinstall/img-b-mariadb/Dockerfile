FROM mariadb:10.1

RUN \
	apt-get update \
	&& \
	DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
		nano \
		locales \
	&& sed -i -e 's/# de_DE.UTF-8 UTF-8/de_DE.UTF-8 UTF-8/' /etc/locale.gen \
	&& sed -i -e 's/# de_DE ISO-8859-1/de_DE ISO-8859-1/' /etc/locale.gen \
	&& sed -i -e 's/# de_DE@euro ISO-8859-15/de_DE@euro ISO-8859-15/' /etc/locale.gen \
	&& echo 'LANG="de_DE.UTF-8"' > /etc/default/locale \
	&& locale-gen de_DE.UTF-8 \
	&& dpkg-reconfigure --frontend=noninteractive locales \
	&& update-locale LANG=de_DE.UTF-8

ENV LANG de_DE.UTF-8
ENV LANGUAGE de
ENV LC_ALL de_DE.UTF-8

# set up timezone
ENV TZ=Europe/Berlin
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# copy bashrc
COPY files/bash/.bashrc /root/.bashrc
# copy helpers
#COPY files/helpers/* /root/
# copy MariaDB-Server config
COPY files/mysql-conf.d/* /etc/mysql/conf.d/
COPY files/mariadb-conf.d/* /etc/mysql/mariadb.conf.d/

#EXPOSE 3306

WORKDIR /root/

#ENTRYPOINT ["docker-entrypoint.sh"]
#CMD ["mysqld"]
