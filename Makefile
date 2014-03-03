LOCAL_RULES := $(wildcard local-*.mk)
include $(LOCAL_RULES)

NACL_VERSION ?= pepper_33
NACL_SDK_PATH ?= $(realpath ..)/nacl_sdk
NACLPORTS_REPO ?= $(realpath ..)/naclports
NACL_SDK_ROOT := $(NACL_SDK_PATH)/$(NACL_VERSION)

NACL_ARCH := pnacl
#NACL_ARCH := i686
#NACL_GLIBC := 1
SDL_CONFIG := $(NACLPORTS_REPO)/src/out/repository/SDL-1.2.14/build-nacl-pnacl/sdl-config

C := $(NACL_SDK_ROOT)/toolchain/mac_pnacl/bin/pnacl-clang
CC := $(NACL_SDK_ROOT)/toolchain/mac_pnacl/bin/pnacl-clang++
LD := $(NACL_SDK_ROOT)/toolchain/mac_pnacl/bin/pnacl-ld
LDFLAGS := -L$(NACL_SDK_ROOT)/lib/pnacl/Debug -lnacl_io
CFLAGS := -I$(NACL_SDK_ROOT)/include

#TARGET_HOST := $(shell $(CC) -dumpmachine)
TARGET_HOST := nacl

export NACL_SDK_ROOT NACL_ARCH NACL_GLIBC SDL_CONFIG C CC LD LDFLAGS CFLAGS

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
	$(MAKE) -C $(NACLPORTS_REPO)/src sdl
	chmod +x $(SDL_CONFIG)
	touch $@

sdl_image.updated: sdl.updated
	$(MAKE) -C $(NACLPORTS_REPO)/src sdl_image
	touch $@	

autoconf.updated: sdl_image.updated
	mkdir bomberclone/build || true
	( cd bomberclone && \
	  ACLOCAL='aclocal -I $(NACLPORTS_REPO)/src/out/repository/SDL-1.2.14' autoreconf --install && \
	  cp -v $(NACLPORTS_REPO)/src/build_tools/config.sub . && \
	  ./configure --host=$(TARGET_HOST) )
## TODO: Fix out-of-tree builds.
#	  cd build && \
#	  ../configure --host=$(TARGET_HOST) )
	touch $@

bootstrap: autoconf.updated
	@echo 'Bootstrapped. `rm *.updated` to rebuild.'

bomberclone: bootstrap
	$(MAKE) -C bomberclone

.PHONY: bootstrap
