# Docker Image sources for mdb-mkinstall

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

## Links
### GitHub
- [mdb-mklive](https://github.com/tsitle/dockerimage-mdb_mklive "GitHub Repository for Docker Image mdb-mklive")

### Docker Hub
- [mdb-mkinstall](https://hub.docker.com/r/tsle/mdb-mkinstall "Docker Hub Repository for Docker Image mdb-mkinstall")
- [mdb-install](https://hub.docker.com/r/tsle/mdb-install "Docker Hub Repository for Docker Image mdb-install")
- [mdb-mariadb](https://hub.docker.com/r/tsle/mdb-mariadb "Docker Hub Repository for Docker Image mdb-mariadb")
- [mdb-nginx](https://hub.docker.com/r/tsle/mdb-nginx "Docker Hub Repository for Docker Image mdb-nginx")
- [mdb-mklive](https://hub.docker.com/r/tsle/mdb-mklive "Docker Hub Repository for Docker Image mdb-mklive")

