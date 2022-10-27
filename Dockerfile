FROM ubuntu
ARG S6_OVERLAY_VERSION=3.1.2.1

RUN apt-get update -y \
	&& apt-get install -y --no-install-recommends \
	curl \
	vim \
	openssh-client \
	openssh-server \
	sshpass \
	netcat \
	nginx \
	xz-utils

COPY /fs-root/ /
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz
ADD https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz /tmp
RUN tar -C / -Jxpf /tmp/s6-overlay-x86_64.tar.xz

RUN ./setup.sh \
	&& rm -f /setup.sh

CMD ["/usr/bin/ssh_port.sh"]
ENTRYPOINT ["/init"]
