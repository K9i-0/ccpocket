FROM alpine:3.20

RUN apk add --no-cache openssh-server netcat-openbsd \
  && adduser -D -s /bin/sh ccpocket \
  && echo "ccpocket:ccpocket" | chpasswd \
  && ssh-keygen -A \
  && mkdir -p /run/sshd

COPY sshd_config /etc/ssh/sshd_config

EXPOSE 22

CMD ["/usr/sbin/sshd", "-D", "-e"]
