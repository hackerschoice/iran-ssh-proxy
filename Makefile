VER := 1.1a

FILES += "iran-ssh-proxy-$(VER)/Makefile"
FILES += "iran-ssh-proxy-$(VER)/Dockerfile"
FILES += "iran-ssh-proxy-$(VER)/fs-root/setup.sh"
FILES += "iran-ssh-proxy-$(VER)/fs-root/var"
FILES += "iran-ssh-proxy-$(VER)/fs-root/usr"
FILES += "iran-ssh-proxy-$(VER)/fs-root/etc/"

TARX = $(shell command -v gtar 2>/dev/null)
ifndef TARX
	TARX := tar
endif

all: Dockerfile
	docker build -t hackerschoice/iran-ssh-proxy .

dist:
	rm -f iran-ssh-proxy-$(VER) 2>/dev/null
	ln -sf . iran-ssh-proxy-$(VER)
	$(TARX) cfz iran-ssh-proxy-$(VER).tar.gz --owner=0 --group=0 $(FILES)
	rm -f iran-ssh-proxy-$(VER)
	ls -al iran-ssh-proxy-$(VER).tar.gz

push: Dockerfile
	docker push hackerschoice/iran-ssh-proxy
