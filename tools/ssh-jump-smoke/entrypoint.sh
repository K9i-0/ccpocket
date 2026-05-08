#!/bin/sh
set -eu

if [ -s /run/ccpocket-smoke/id_ed25519.pub ]; then
  install -d -m 700 -o ccpocket -g ccpocket /home/ccpocket/.ssh
  cp /run/ccpocket-smoke/id_ed25519.pub /home/ccpocket/.ssh/authorized_keys
  chown ccpocket:ccpocket /home/ccpocket/.ssh/authorized_keys
  chmod 600 /home/ccpocket/.ssh/authorized_keys
fi

exec /usr/sbin/sshd -D -e
