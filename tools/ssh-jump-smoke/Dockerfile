FROM alpine:3.20

RUN apk add --no-cache openssh-server netcat-openbsd \
  && adduser -D -s /bin/sh ccpocket \
  && echo "ccpocket:ccpocket" | chpasswd \
  && ssh-keygen -A \
  && install -d -m 700 -o ccpocket -g ccpocket /home/ccpocket/.ssh \
  && mkdir -p /run/sshd

COPY sshd_config /etc/ssh/sshd_config
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

EXPOSE 22

CMD ["/entrypoint.sh"]
