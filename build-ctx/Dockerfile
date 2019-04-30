FROM scratch

ARG CF_CPUARCH_DEB_ROOTFS
ARG CF_CPUARCH_DEB_DIST

# source for rootfs: https://github.com/debuerreotype/docker-debian-artifacts/tree/dist-<CF_CPUARCH_DEB_ROOTFS>/stretch
ADD files/src-mkinstall/build-ctx/img-0-common/rootfs-debian_stretch_9.8-${CF_CPUARCH_DEB_ROOTFS}.tar.xz /

WORKDIR /root

RUN \
	# install packages
		apt-get update \
		&& DEBIAN_FRONTEND=noninteractive apt-get upgrade -y --no-install-recommends \
		&& DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
			# mandatory packages \
				nano \
				less \
				locales \
				procps \
			# Docker CE packages \
				apt-transport-https \
				ca-certificates \
				curl \
				gnupg2 \
				software-properties-common \
	# add Docker's official GPG key
		&& curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add - \
	# add Docker's stable repository
		&& add-apt-repository \
				"deb [arch=${CF_CPUARCH_DEB_DIST}] https://download.docker.com/linux/debian \
				$(lsb_release -cs) \
				stable" \
		&& apt-get update \
	# install Docker
		&& DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
				docker-ce docker-ce-cli containerd.io \
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

# copy mkinstall sourcecode
COPY files/src-mkinstall /root/
# copy bashrc
COPY files/src-mkinstall/build-ctx/img-0-common/bash/dot_bashrc /root/.bashrc

RUN \
	# mkinstall sourcecode
		chmod 755 /root/mkinstall-real.sh \
	# Bash
		&& chmod 640 /root/.bashrc \
		&& chown root:root /root/.bashrc

ENTRYPOINT ["/root/mkinstall-real.sh"]
