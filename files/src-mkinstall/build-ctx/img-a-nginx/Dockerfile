FROM scratch

ARG CF_CPUARCH_DEB_ROOTFS

# source for rootfs: https://github.com/debuerreotype/docker-debian-artifacts/tree/dist-<CF_CPUARCH_DEB_ROOTFS>/stretch
ADD img-0-common/rootfs-debian_stretch_9.8-${CF_CPUARCH_DEB_ROOTFS}.tar.xz /

WORKDIR /root

RUN \
	# install packages
		apt-get update \
		&& DEBIAN_FRONTEND=noninteractive apt-get upgrade -y --no-install-recommends \
		&& DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
			# mandatory packages \
				wget \
				nano \
				less \
				locales \
				procps \
				ca-certificates \
				openssl \
			# nginx package
				nginx \
	# forward request and error logs to docker log collector
		&& ln -sf /dev/stdout /var/log/nginx/access.log \
		&& ln -sf /dev/stderr /var/log/nginx/error.log \
	# set locales
		&& locale-gen de_DE.UTF-8 \
		&& sed -i -e 's/# de_DE.UTF-8 UTF-8/de_DE.UTF-8 UTF-8/' /etc/locale.gen \
		&& sed -i -e 's/# de_DE ISO-8859-1/de_DE ISO-8859-1/' /etc/locale.gen \
		&& sed -i -e 's/# de_DE@euro ISO-8859-15/de_DE@euro ISO-8859-15/' /etc/locale.gen \
		&& echo 'LANG="de_DE.UTF-8"'>/etc/default/locale \
		&& dpkg-reconfigure --frontend=noninteractive locales \
		&& update-locale LANG=de_DE.UTF-8

ENV LANG de_DE.UTF-8
ENV LANGUAGE de
ENV LC_ALL de_DE.UTF-8

# set up timezone
ENV TZ=Europe/Berlin
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# startup script
COPY img-a-nginx/files/start.sh /start.sh

# SSL Cert/Key script
COPY \
	img-0-common/sslgen.sh \
	img-0-common/pwgen.sh \
	/root/

# copy bashrc
COPY img-0-common/bash/dot_bashrc /root/.bashrc

# copy virtual host configs
COPY img-a-nginx/files/nginx-vhosts/* /etc/nginx/sites-available/

RUN \
	# remove default sites
		rm -f /etc/nginx/sites-enabled/* \
	# enable VHost site
		&& chmod 644 /etc/nginx/sites-available/* \
		&& chown root:root /etc/nginx/sites-available/* \
		&& rm /etc/nginx/sites-available/default \
		&& ln -fs ../sites-available/030-default-http /etc/nginx/sites-enabled/ \
		&& ln -fs ../sites-available/031-default-https /etc/nginx/sites-enabled/ \
	# default host's index html file
		&& mv /var/www/html/index.nginx-debian.html /var/www/html/index.html \
	# add default location
		&& mkdir /etc/ssl/host-keys /etc/ssl/host-certs \
		&& mkdir /etc/ssl/host-keys-internal /etc/ssl/host-certs-internal \
	# Bash
		&& chmod 640 /root/.bashrc \
		&& chown root:root /root/.bashrc \
	# user scripts
		&& chmod 755 /start.sh /root/sslgen.sh /root/pwgen.sh \
		&& chown root:root /start.sh /root/sslgen.sh /root/pwgen.sh

EXPOSE 80 443

STOPSIGNAL SIGTERM

CMD ["/start.sh"]
