#
# Debian Stretch 9.8
# + Apache
# + GIT
# + Midnight Commander
# + Less
# + Nano
# + Vim
# + MariaDB Client
# + Modoboa Packages #1 (Python, Amavis, AutoMX, Dovecot, Postfix, Razor, SpamAssassin, Radicale, Sudo, Wget)
#

FROM scratch

ARG CF_CPUARCH_DEB_ROOTFS

# source for rootfs: https://github.com/debuerreotype/docker-debian-artifacts/tree/dist-<CF_CPUARCH_DEB_ROOTFS>/stretch
ADD img-0-common/rootfs-debian_stretch_9.8-${CF_CPUARCH_DEB_ROOTFS}.tar.xz /

WORKDIR /root

EXPOSE 80 443 25 587 993

RUN \
	apt-get update \
	&& \
	DEBIAN_FRONTEND=noninteractive apt-get upgrade -y --no-install-recommends \
	&& \
	DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
		ca-certificates \
		ssl-cert \
		less \
		nano \
		vim \
		apache2 \
		libapache2-mod-wsgi \
		mc \
		git \
		inetutils-syslogd \
		net-tools

RUN \
	apt-get update \
	&& \
	DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
		locales \
	&& rm -rf /var/lib/apt/lists/* \
	&& locale-gen de_DE.UTF-8 \
	&& sed -i -e 's/# de_DE.UTF-8 UTF-8/de_DE.UTF-8 UTF-8/' /etc/locale.gen \
	&& sed -i -e 's/# de_DE ISO-8859-1/de_DE ISO-8859-1/' /etc/locale.gen \
	&& sed -i -e 's/# de_DE@euro ISO-8859-15/de_DE@euro ISO-8859-15/' /etc/locale.gen \
	&& echo 'LANG="de_DE.UTF-8"'>/etc/default/locale \
	&& dpkg-reconfigure --frontend=noninteractive locales \
	&& update-locale LANG=de_DE.UTF-8

ENV LANG=de_DE.UTF-8
ENV LANGUAGE=de
ENV LC_ALL=de_DE.UTF-8
ENV TZ=Europe/Berlin

RUN \
	ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
	&& echo $TZ > /etc/timezone

RUN \
	# to enable CSRF-Protection in Apache
	a2enmod headers \
	; \
	# to enable Reverse Proxy in Apache
	a2enmod proxy proxy_http ssl

RUN \
	apt-get update \
	&& \
	DEBIAN_FRONTEND=noninteractive apt-get remove -y \
		exim4 exim4-base exim4-config exim4-daemon-light \
	; \
	DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
		mariadb-client-10.1 \
		# Amavis
		libdbi-perl arj libdbd-mysql-perl amavisd-new arc cabextract liblz4-tool lrzip lzop p7zip-full rpm2cpio unrar-free zoo ripole \
		# AutoMX
		memcached unzip \
		# Dovecot
		dovecot-imapd dovecot-lmtpd dovecot-managesieved dovecot-sieve dovecot-mysql \
		# Postfix
		postfix postfix-mysql \
		# Razor
		razor \
		# SpamAssassin
		spamassassin pyzor \
	&& \
	# Modoboa Base
		DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
			build-essential python-dev libxml2-dev libxslt-dev libjpeg-dev librrd-dev rrdtool libffi-dev cron \
			libssl-dev \
			libmariadbclient-dev \
			python-pip python-virtualenv virtualenv \
			sudo wget \
	&& \
	ln -s /usr/sbin/nologin /sbin/nologin \
	&& \
	# Radicale
		DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
			python3-pip python3-setuptools python3-wheel python3-passlib python3-bcrypt \
			python-meld3 supervisor python3-venv python3.5-venv \
		&& \
		python3 -m pip install --upgrade radicale \
		&& \
		useradd --system --home-dir / --shell /sbin/nologin radicale

RUN \
	pip3 install radicale-dovecot-auth \
	&& \
	pip3 install pytz \
	&& \
	cd /root \
	&& \
	git clone https://github.com/tonioo/RadicaleStorageByIndex \
	&& \
	cd RadicaleStorageByIndex \
	&& \
	python3 ./setup.py install \
	&& \
	cd .. \
	&& \
	rm -r RadicaleStorageByIndex

COPY img-0-common/bash/dot_bashrc .bashrc
COPY img-c-step1/files/docker-entrypoint.sh /usr/local/bin/
COPY img-c-step1/files/root_mc/ini .config/mc/
COPY \
	img-0-common/pwgen.sh \
	img-c-step1/files/customize_modo_lconf.py \
	./

RUN \
	chmod 640 .bashrc \
	&& \
	chown root:root .bashrc \
	&& \
	echo "alias ll='ls -l'" >> .profile \
	&& \
	echo "alias la='ls -la'" >> .profile \
	&& \
	chmod 755 \
			/usr/local/bin/docker-entrypoint.sh \
			pwgen.sh \
	&& \
	chown root:root \
			/usr/local/bin/docker-entrypoint.sh \
			.config/mc/ini \
			pwgen.sh \
			customize_modo_lconf.py

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["bash"]
