#
# Based on
#   https://github.com/linuxserver/docker-mariadb
# and
#   https://github.com/linuxserver/docker-baseimage-ubuntu branch bionic
#

FROM scratch

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
# beg lsio-baseimage_ubuntu_bionic (v18.04.2)
# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
ARG CF_CPUARCH_DEB_DIST
ENV CF_CPUARCH_DEB_DIST=${CF_CPUARCH_DEB_DIST}

ARG CF_CPUARCH_S6_OVERLAY
ENV CF_CPUARCH_S6_OVERLAY=${CF_CPUARCH_S6_OVERLAY}

ARG CF_CPUARCH_QEMU
ENV CF_CPUARCH_QEMU=${CF_CPUARCH_QEMU}

ENV REL=bionic

ARG ARCH=${CF_CPUARCH_DEB_DIST}
ENV ARCH=${ARCH}

ADD img-b-mariadb/files/lsio-baseimage_ubuntu_bionic/ubuntu-bionic-core-cloudimg-${ARCH}-root.tgz /

# set version for s6 overlay
ARG OVERLAY_VERSION="v1.22.0.0"
ARG OVERLAY_ARCH=${CF_CPUARCH_S6_OVERLAY}

# set environment variables
ARG DEBIAN_FRONTEND="noninteractive"
ENV HOME="/root" \
LANGUAGE="en_US.UTF-8" \
LANG="en_US.UTF-8" \
TERM="xterm"

# copy S6 overlay tarball
COPY img-b-mariadb/files/lsio-baseimage_ubuntu_bionic/s6-overlay-${OVERLAY_VERSION}-${OVERLAY_ARCH}.tgz /tmp/

# copy QEMU
COPY img-b-mariadb/files/lsio-baseimage_ubuntu_bionic/qemu-${CF_CPUARCH_QEMU}-static /usr/bin/

# copy sources
COPY img-b-mariadb/files/lsio-baseimage_ubuntu_bionic/sources.list.${CF_CPUARCH_DEB_DIST} /etc/apt/

RUN \
	#
	echo "**** Ripped from Ubuntu Docker Logic ****" && \
	set -xe \
	&& echo '#!/bin/sh' \
			> /usr/sbin/policy-rc.d \
	&& echo 'exit 101' \
			>> /usr/sbin/policy-rc.d \
	&& chmod +x \
			/usr/sbin/policy-rc.d \
	&& dpkg-divert --local --rename --add /sbin/initctl \
	&& cp -a \
			/usr/sbin/policy-rc.d \
			/sbin/initctl \
	&& sed -i \
			's/^exit.*/exit 0/' \
			/sbin/initctl \
	&& echo 'force-unsafe-io' \
			> /etc/dpkg/dpkg.cfg.d/docker-apt-speedup \
	&& echo 'DPkg::Post-Invoke { "rm -f /var/cache/apt/archives/*.deb /var/cache/apt/archives/partial/*.deb /var/cache/apt/*.bin || true"; };' \
			> /etc/apt/apt.conf.d/docker-clean \
	&& echo 'APT::Update::Post-Invoke { "rm -f /var/cache/apt/archives/*.deb /var/cache/apt/archives/partial/*.deb /var/cache/apt/*.bin || true"; };' \
			>> /etc/apt/apt.conf.d/docker-clean \
	&& echo 'Dir::Cache::pkgcache ""; Dir::Cache::srcpkgcache "";' \
			>> /etc/apt/apt.conf.d/docker-clean \
	&& echo 'Acquire::Languages "none";' \
			> /etc/apt/apt.conf.d/docker-no-languages \
	&& echo 'Acquire::GzipIndexes "true"; Acquire::CompressionTypes::Order:: "gz";' \
			> /etc/apt/apt.conf.d/docker-gzip-indexes \
	&& echo 'Apt::AutoRemove::SuggestsImportant "false";' \
			> /etc/apt/apt.conf.d/docker-autoremove-suggests \
	&& mkdir -p /run/systemd \
	&& echo 'docker' \
			> /run/systemd/container \
	#
	&& \
	echo "**** install apt-utils and locales ****" && \
	apt-get update \
	&& apt-get install -y \
			apt-utils \
			locales \
	#
	&& \
	echo "**** install packages ****" && \
	apt-get install -y \
			curl \
			tzdata \
	#
	&& \
	echo "**** generate locale ****" && \
	locale-gen en_US.UTF-8 \
	#
	&& \
	echo "**** add s6 overlay ****" && \
	# ------------------------------------------------
	#curl -o \
	#		/tmp/s6-overlay.tar.gz -L \
	#		"https://github.com/just-containers/s6-overlay/releases/download/${OVERLAY_VERSION}/s6-overlay-${OVERLAY_ARCH}.tar.gz" \
	#&& tar xfz \
	#		/tmp/s6-overlay.tar.gz -C / \
	tar xzf \
			/tmp/s6-overlay-${OVERLAY_VERSION}-${OVERLAY_ARCH}.tgz -C / \
	# ------------------------------------------------
	#
	&& \
	echo "**** create abc user and make our folders ****" && \
	useradd -u 911 -U -d /config -s /bin/false abc \
	&& usermod -G users abc \
	&& mkdir -p \
			/app \
			/config \
			/defaults \
	&& if [ "$ARCH" != "amd64" ]; then \
			echo "**** add qemu ****"; \
			# ------------------------------------------------
			#curl -o \
			#		/usr/bin/qemu-${CF_CPUARCH_QEMU}-static -L \
			#		"https://lsio-ci.ams3.digitaloceanspaces.com/qemu-${CF_CPUARCH_QEMU}-static" \
			chmod +x /usr/bin/qemu-${CF_CPUARCH_QEMU}-static \
			# ------------------------------------------------
			; \
		else \
			echo -n; \
		fi \
	#
	&& \
	echo "**** cleanup ****" && \
	apt-get clean \
	&& rm -rf \
			/tmp/* \
			/var/lib/apt/lists/* \
			/var/tmp/*

# add local files
COPY img-b-mariadb/files/lsio-baseimage_ubuntu_bionic/fs_root/ /

ENTRYPOINT ["/init"]
# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
# end lsio-baseimage_ubuntu_bionic
# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
# beg lsio-mariadb (v10.1)
# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
ARG MARIADB_REPO_VERSION=10.1
ARG MARIADB_VERSION

# environment variables
ARG DEBIAN_FRONTEND="noninteractive"
ENV MYSQL_DIR="/config"
#ENV DATADIR=$MYSQL_DIR/databases
ENV DATADIR=/var/lib/mysql

RUN \
	echo "**** install gnupg ****" && \
	apt-get update \
	&& apt-get install -y \
			gnupg \
	#
	&& \
	echo "add mariadb repository ****" && \
	echo "(redundant on armhf platform, but added for consistent dockerfile on all platforms) ****" && \
	apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xF1656F24C74CD1D8 \
	&& echo "deb http://mirror.sax.uk.as61049.net/mariadb/repo/${MARIADB_REPO_VERSION}/ubuntu bionic main" >> \
			/etc/apt/sources.list.d/mariadb.list \
	&& echo "deb-src http://mirror.sax.uk.as61049.net/mariadb/repo/${MARIADB_REPO_VERSION}/ubuntu bionic main" >> \
			/etc/apt/sources.list.d/mariadb.list \
	#
	&& \
	echo "**** install runtime packages ****" && \
	if [ -z ${MARIADB_VERSION+x} ]; then \
			MARIADB="mariadb-server"; \
		else \
			MARIADB="mariadb-server=${MARIADB_VERSION}"; \
		fi \
	&& apt-get update \
	&& apt-get install -y \
			${MARIADB} \
	#
	&& \
	echo "**** cleanup ****" && \
	rm -rf \
			/tmp/* \
			/var/lib/apt/lists/* \
			/var/lib/mysql \
			/var/tmp/* \
	&& mkdir -p \
			/var/lib/mysql

# add local files
COPY img-b-mariadb/files/lsio-mariadb/fs_root/ /

EXPOSE 3306

#VOLUME /config
VOLUME /var/lib/mysql
# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------
# end lsio-mariadb (v10.1)
# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------

RUN \
	apt-get update \
	&& \
	DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
		nano \
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
COPY img-0-common/bash/dot_bashrc /root/.bashrc

# startup script
COPY img-b-mariadb/files/custom/docker-entrypoint.sh /usr/local/bin/

RUN \
	chmod 755 /usr/local/bin/docker-entrypoint.sh \
	&& chown root:root /usr/local/bin/docker-entrypoint.sh

#EXPOSE 3306

WORKDIR /root/

ENTRYPOINT ["docker-entrypoint.sh"]
