LOCAL_RULES := $(wildcard local-*.mk)
include $(LOCAL_RULES)

SYSTEM := $(shell uname -s)
TOOLCHAIN_PREFIX ?= $(if \
  $(findstring Darwin, $(SYSTEM)),mac,$(if \
    $(findstring CYGWIN, $(SYSTEM)),win,linux))

NACL_VERSION ?= pepper_33
NACL_TOOLCHAIN ?= $(TOOLCHAIN_PREFIX)_pnacl

NACL_SDK_PATH ?= $(realpath ..)/nacl_sdk
NACLPORTS_REPO ?= $(realpath ..)/naclports
NACL_SDK_ROOT := $(NACL_SDK_PATH)/$(NACL_VERSION)

GCLIENT ?= $(shell which gclient)
AUTOMAKE ?= $(shell which gclient)

NACL_ARCH := pnacl

TOOLCHAIN_PATH := $(NACL_SDK_ROOT)/toolchain/$(NACL_TOOLCHAIN)
C := $(TOOLCHAIN_PATH)/bin/pnacl-clang
CC := $(TOOLCHAIN_PATH)/bin/pnacl-clang++
LD := $(TOOLCHAIN_PATH)/bin/pnacl-ld
SDL_CONFIG := $(TOOLCHAIN_PATH)/usr/bin/sdl-config

PNACL_FINALIZE := $(TOOLCHAIN_PATH)/bin/pnacl-finalize
LDFLAGS := -L$(NACL_SDK_ROOT)/lib/pnacl/Debug -lnacl_io
CFLAGS := -I$(NACL_SDK_ROOT)/include -O2

#TARGET_HOST := $(shell $(CC) -dumpmachine)
TARGET_HOST := nacl

export NACL_SDK_ROOT NACL_ARCH NACL_GLIBC
export C CC LD LDFLAGS CFLAGS SDL_CONFIG

all: app

requirements.updated: $(GCLIENT) $(AUTOMAKE)
	@test -n "$(GCLIENT)" || (echo "glcient required - unable to find gclient in PATH" && false)
	@test -n "$(AUTOMAKE)" || (echo " autotools required - unable to find automake in PATH" && false)
	touch $@

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

naclsdk.updated: $(NACL_SDK_PATH)/naclsdk
	$< update
	touch $@

naclports.updated: requirements.updated
	test -n "$(NACLPORTS_REPO)"
	mkdir "$(NACLPORTS_REPO)" || true
	( cd $(NACLPORTS_REPO) && \
	  $(GCLIENT) config --name=src  https://chromium.googlesource.com/external/naclports.git && \
          $(GCLIENT) sync )
	touch $@

sdl.updated: naclsdk.updated naclports.updated
	unset SDL_CONFIG && $(MAKE) -C $(NACLPORTS_REPO)/src sdl
	chmod +x $(SDL_CONFIG)
	touch $@

sdl_libs.updated: sdl.updated
	$(MAKE) -C $(NACLPORTS_REPO)/src sdl_image sdl_mixer
	touch $@

autoconf.updated: sdl_libs.updated
	mkdir bomberclone/build || true
	( cd bomberclone && \
	  ACLOCAL='aclocal -I $(NACLPORTS_REPO)/src/out/repository/SDL-1.2.14' autoreconf --install && \
	  cp -v $(NACLPORTS_REPO)/src/build_tools/config.sub . && \
	  ./configure --host=$(TARGET_HOST) --disable-debug)
	touch $@

bootstrap: autoconf.updated
	@echo 'Bootstrapped. `rm *.updated` to rebuild.'

bomberclone: bootstrap
	$(MAKE) -C bomberclone

app: bomberclone
	cp bomberclone/src/bomberclone app/bomberclone.pexe
	$(PNACL_FINALIZE) app/bomberclone.pexe
	(cd bomberclone && tar -c --exclude='Makefile*' --exclude=CVS --exclude=.* data) | (cd app && tar x)

.PHONY: bootstrap app
