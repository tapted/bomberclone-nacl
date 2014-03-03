LOCAL_RULES := $(wildcard local-*.mk)
include $(LOCAL_RULES)

NACL_SDK_PATH ?= $(realpath ..)/nacl_sdk

all: bootstrap

$(NACL_SDK_PATH)/naclsdk:
	test -n "$(NACL_SDK_PATH)"
	mkdir "$(NACL_SDK_PATH)" || true
	( cd $(NACL_SDK_PATH) && \
	  curl -O http://storage.googleapis.com/nativeclient-mirror/nacl/nacl_sdk/nacl_sdk.zip && \
	  unzip nacl_sdk.zip && \
	  rm nacl_sdk.zip && \
	  mv nacl_sdk/* . && \
	  rmdir nacl_sdk && \
	  touch naclsdk)

naclsdk: $(NACL_SDK_PATH)/naclsdk
	$< update

bootstrap: naclsdk
	echo "Bootstrapped."

.PHONY: naclsdk bootstrap
