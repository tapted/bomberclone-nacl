LOCAL_RULES := $(wildcard local-*.mk)
include $(LOCAL_RULES)

NACL_VERSION ?= pepper_33
#NACL_ARCH := pnacl
NACL_ARCH := i686
NACL_GLIBC := 1

NACL_SDK_PATH ?= $(realpath ..)/nacl_sdk
NACLPORTS_REPO ?= $(realpath ..)/naclports
NACL_SDK_ROOT := $(NACL_SDK_PATH)/$(NACL_VERSION)

export NACL_SDK_ROOT NACL_ARCH NACL_GLIBC

all: bomberclone

$(NACL_SDK_PATH)/naclsdk:
	test -n "$(NACL_SDK_PATH)"
	mkdir "$(NACL_SDK_PATH)" || true
	( cd $(NACL_SDK_PATH) && \
	  curl -O http://storage.googleapis.com/nativeclient-mirror/nacl/nacl_sdk/nacl_sdk.zip && \
	  unzip nacl_sdk.zip && \
	  rm nacl_sdk.zip && \
	  mv nacl_sdk/* . && \
	  rmdir nacl_sdk && \
	  touch naclsdk )

$(NACLPORTS_REPO)/src/Makefile:
	test -n "$(NACLPORTS_REPO)"
	mkdir "$(NACLPORTS_REPO)" || true
	( cd $(NACLPORTS_REPO) && \
	  gclient config --name=src  https://chromium.googlesource.com/external/naclports.git )

naclsdk.updated: $(NACL_SDK_PATH)/naclsdk
	$< update
	touch $@

naclports.updated: $(NACLPORTS_REPO)/src/Makefile
	( cd $(NACLPORTS_REPO) && gclient sync )
	touch $@

sdl.updated: naclsdk.updated naclports.updated
	$(MAKE) -C $(NACLPORTS_REPO)/src sdl sdl_image
	touch $@

autoconf.updated: sdl.updated
	mkdir bomberclone/build || true
	( cd bomberclone && \
	  ACLOCAL='aclocal -I $(NACLPORTS_REPO)/src/out/repository/SDL-1.2.14' autoreconf && \
	  cd build && \
	  ../configure )
	touch $@

bootstrap: autoconf.updated
	@echo 'Bootstrapped. `rm *.updated` to rebuild.'

bomberclone: bootstrap
	$(MAKE) -C bomberclone/build

.PHONY: bootstrap
