FROM alpine:3.20

RUN apk add --no-cache openssh-server netcat-openbsd nodejs \
  && adduser -D -s /bin/sh ccpocket \
  && echo "ccpocket:ccpocket" | chpasswd \
  && ssh-keygen -A \
  && install -d -m 700 -o ccpocket -g ccpocket /home/ccpocket/.ssh \
  && mkdir -p /run/sshd

COPY sshd_config /etc/ssh/sshd_config
COPY entrypoint.sh /entrypoint.sh
COPY bridge-smoke-server.mjs /bridge-smoke-server.mjs

RUN chmod +x /entrypoint.sh

EXPOSE 22
EXPOSE 8765

CMD ["/entrypoint.sh"]
