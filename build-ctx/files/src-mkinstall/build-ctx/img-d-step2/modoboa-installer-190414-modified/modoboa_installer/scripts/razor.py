"""Razor related functions."""

import os
import pwd
import stat

from .. import utils

from . import base


class Razor(base.Installer):

    """Razor installer."""

    appname = "razor"
    no_daemon = True
    packages = {
        "deb": ["razor"],
        "rpm": ["perl-Razor-Agent"]
    }

    def post_run(self):
        """Additional tasks."""
        user = self.config.get("amavis", "user")
        pw = pwd.getpwnam(user)
        utils.mkdir(
            "/var/log/razor",
            stat.S_IRWXU | stat.S_IRGRP | stat.S_IXGRP |
            stat.S_IROTH | stat.S_IXOTH,
            pw[2], pw[3]
        )
        path = os.path.join(pw[5], ".razor")
        utils.mkdir(path, stat.S_IRWXU, pw[2], pw[3])
        utils.exec_cmd("razor-admin -home {} -create".format(path))
        utils.mkdir(
            self.config_dir,
            stat.S_IRWXU | stat.S_IRGRP | stat.S_IXGRP |
            stat.S_IROTH | stat.S_IXOTH,
            0, 0
        )
        utils.copy_file(
            os.path.join(path, "razor-agent.conf"), self.config_dir)
        utils.exec_cmd("razor-admin -home {} -discover".format(path),
                       sudo_user=user, login=False)
        utils.exec_cmd("razor-admin -home {} -register".format(path),
                       sudo_user=user, login=False)
        # FIXME: move log file to /var/log ?
