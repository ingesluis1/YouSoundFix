TARGET := iphone:clang:latest:14.0
ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = YouTube

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = YouSoundFix
YouSoundFix_FILES = Tweak.x
YouSoundFix_CFLAGS = -fobjc-arc
YouSoundFix_FRAMEWORKS = AVFoundation
# Geen CydiaSubstrate nodig: werkt zo los in LiveContainer en in een IPA.
YouSoundFix_LOGOS_DEFAULT_GENERATOR = internal

include $(THEOS_MAKE_PATH)/tweak.mk
