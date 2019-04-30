#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#

"""
Radicale WSGI file (mod_wsgi and uWSGI compliant).

"""

import os

import radicale
from radicale import Application, config, log

config_paths = []
os.environ['RADICALE_CONFIG'] = '/etc/radicale/config'
#if os.environ.get("RADICALE_CONFIG"):
#    config_paths.append(os.environ["RADICALE_CONFIG"])
configuration = config.load(config_paths, ignore_missing_paths=False)
filename = os.path.expanduser(configuration.get("logging", "config"))
debug = configuration.getboolean("logging", "debug")
logger = log.start("radicale", filename, debug)

radicale.log.start()
application = radicale.Application(configuration, logger)
