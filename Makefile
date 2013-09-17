TARGET := iphone:5.1:2.0
ARCHS := armv6
PACKAGE_VERSION := $(shell ./version.sh)

include theos/makefiles/common.mk

TWEAK_NAME := MobileSafety
MobileSafety_FILES := Tweak.xm
MobileSafety_FRAMEWORKS := UIKit

include $(THEOS_MAKE_PATH)/tweak.mk
