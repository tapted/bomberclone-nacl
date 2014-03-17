LOCAL_RULES := $(wildcard local-*.mk)
include $(LOCAL_RULES)

SYSTEM := $(shell uname -s)
TOOLCHAIN_PREFIX ?= $(if \
  $(findstring Darwin, $(SYSTEM)),mac,$(if \
    $(findstring CYGWIN, $(SYSTEM)),win,linux))

NACL_VERSION ?= pepper_33
NACL_TOOLCHAIN ?= $(TOOLCHAIN_PREFIX)_pnacl

## Comment these out if you don't want debugging / optimizations
DEBUG_FLAGS := -g
#OPT_FLAGS := -O2

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

PNACL_FINALIZE := echo $(TOOLCHAIN_PATH)/bin/pnacl-finalize
PNACL_TRANSLATE := $(TOOLCHAIN_PATH)/bin/pnacl-translate --allow-llvm-bitcode-input

LDFLAGS := -L$(NACL_SDK_ROOT)/lib/pnacl/Debug -lnacl_io
CFLAGS := -I$(NACL_SDK_ROOT)/include $(DEBUG_FLAGS) $(OPT_FLAGS)

#TARGET_HOST := $(shell $(CC) -dumpmachine)
TARGET_HOST := nacl

COMMON_FILES := manifest.json styles.css main.js .bomberclone.cfg app_assets data
APP_FILES := $(COMMON_FILES) bomberclone.nmf main.html window.js bomberclone.pexe
DBGAPP_FILES := $(COMMON_FILES) bomberclone-debug.nmf main-debug.html window-debug.js bomberclone_x86_32.nexe bomberclone_x86_64.nexe

export NACL_SDK_ROOT NACL_ARCH NACL_GLIBC
export C CC LD LDFLAGS CFLAGS SDL_CONFIG

all: app

%_x86_32.nexe: %.pexe
	$(PNACL_TRANSLATE) $< -arch x86-32 -o $@

%_x86_64.nexe: %.pexe
	$(PNACL_TRANSLATE) $< -arch x86-64 -o $@

%.json.updated: app/%.json
	rm *.json.updated || true
	cp $< app/manifest.json
	touch $@

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

bomberclone/src/bomberclone: bootstrap
	$(MAKE) -C bomberclone

clean:
	$(MAKE) -C bomberclone clean

app/bomberclone.pexe: bomberclone/src/bomberclone
	cp bomberclone/src/bomberclone app/bomberclone.pexe

assets:
	(cd bomberclone && tar -c --exclude='Makefile*' --exclude=CVS --exclude=.* data) | (cd app && tar x)

dbgapp: app/bomberclone_x86_32.nexe app/bomberclone_x86_64.nexe assets

app: app/bomberclone.pexe assets manifest-rel.json.updated
	$(PNACL_FINALIZE) app/bomberclone.pexe

bomberclone-app.zip: manifest-rel.json.updated
	rm $@
	(cd app && zip -9 -r ../$@ $(APP_FILES))

dbgapp: app/bomberclone_x86_32.nexe app/bomberclone_x86_64.nexe assets manifest-debug.json.updated

bomberclone-app-DEBUG.zip: manifest-debug.json.updated
	rm $@
	(cd app && zip -9 -r ../$@ $(DBGAPP_FILES))

zip: bomberclone-app.zip
dbgzip: bomberclone-app-DEBUG.zip

.PHONY: bootstrap app dbgapp assets clean zip dbgzip
