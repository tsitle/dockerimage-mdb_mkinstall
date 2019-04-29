# Docker Image sources for mdb-mkinstall

If you're just looking to run a dockerized Mailserver you may head directly to the GitHub Repository for **mdb-dc-mklive** (see link below).  

--

Docker Image for building the **mdb-install**, **mdb-mariadb** and **mdb-nginx** Docker Images.

These images are required for using the Docker Image **mdb-mklive**.

The Docker Images **mdb-install**, **mdb-mariadb** and **mdb-nginx** will contain all necessary software components for setting up a fully featured dockerized Mailserver:

- Modoboa Webinterface for  
	- domain and user management
	- webmailer
	- managing calenders and contacts
	- managing autoresponse emails
- SpamAssassin Anti-Spam-Filter
- Postfix SMTP Server
- Dovecot IMAP Server
- ClamAV Virus Scanner
- AutoMX for automated mail account configuration in email clients
- Radicale CalDAV and CardDAV Server
- MariaDB Database Server
- OpenDKIM for automaticly signing outgoing emails to reduce risk of emails being falsely classified as spam
- Apache Webserver for handling requests to the Modoboa Webinterface, AutoMX and Radicale within the Docker Container running **mdb-live**
- Nginx Reverse Proxy for forwarding requests from the outside world to the Apache Webserver

Note that the Docker Image **mdb-install** is not intended to be used directly as a Mailserver.  
Instead, use **mdb-mklive** to generate a Docker Image with your custom settings.

In order to use this Docker Image you should also get a copy of the Docker Container Repository **mdb-dc-mkinstall** (see below).

## Links
### GitHub
- GitHub Repository for Docker Image [mdb-mkinstall](https://github.com/tsitle/dockerimage-mdb_mkinstall)
- GitHub Repository for Docker Container [mdb-dc-mkinstall](https://github.com/tsitle/dockercontainer-mdb_dc_mkinstall)
- GitHub Repository for Docker Image [mdb-mklive](https://github.com/tsitle/dockerimage-mdb_mklive)
- GitHub Repository for Docker Container [mdb-dc-mklive](https://github.com/tsitle/dockercontainer-mdb_dc_mklive)

### Docker Hub
- Docker Hub Repositories [tsle/](https://hub.docker.com/r/tsle/)
