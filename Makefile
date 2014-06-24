TARGET := iphone:7.1:6.0
TARGET := iphone:clang
ARCHS = armv7 armv7s arm64
PACKAGE_VERSION := $(shell ./version.sh)

include theos/makefiles/common.mk

TWEAK_NAME := MobileSafety
MobileSafety_FILES := Tweak.xm
MobileSafety_FRAMEWORKS := UIKit
MobileSafety_LIBRARIES = substrate

include $(THEOS_MAKE_PATH)/tweak.mk