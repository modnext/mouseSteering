## Config
GAME_NAME = FarmingSimulator2025
MOD_NAME = FS25_mouseSteering

## Paths (override on CLI if needed)
MS_STORE_SOURCE_DIR = E:/WpSystem/S-1-5-21-3088201243-2015716805-163762165-1008/AppData/Local/Packages/GIANTSSoftware.FarmingSimulator25PC_fa8jxm5fj0esw/LocalCache/Local/mods
SOURCE_DIR = C:/Mods/$(GAME_NAME)/$(MOD_NAME)
DEST_DIR   = C:/Mods/$(GAME_NAME)

## Package contents
FILES  = modDesc.xml icon_mouseSteering.dds
DIRS   = src l10n data
PKG    = $(FILES) $(DIRS)

## Artifacts
DEV_ZIP = $(MOD_NAME)_dev.zip
REL_ZIP = $(MOD_NAME).zip

## Tools
PS  = powershell -NoProfile -ExecutionPolicy Bypass -Command
ZIP = zip -r

.PHONY: all dev build clean

all: build

## Build dev zip and copy to game Mods folder
dev:
	cd "$(SOURCE_DIR)" && $(ZIP) "$(DEV_ZIP)" $(PKG)
	$(PS) "Move-Item -Path \"$(SOURCE_DIR)/$(DEV_ZIP)\" -Destination \"$(DEST_DIR)\" -Force"
ifneq ($(MS_STORE_SOURCE_DIR),)
	$(PS) "Copy-Item -Path \"$(DEST_DIR)/$(DEV_ZIP)\" -Destination \"$(MS_STORE_SOURCE_DIR)\" -Force"
endif

## Build release zip and move to dist folder
build:
	cd "$(SOURCE_DIR)" && $(ZIP) "$(REL_ZIP)" $(PKG)
	$(PS) "Move-Item -Path \"$(SOURCE_DIR)/$(REL_ZIP)\" -Destination \"$(DEST_DIR)\" -Force"

## Remove dev and release artifacts
clean:
	$(PS) 'if (Test-Path "$(DEST_DIR)/$(DEV_ZIP)") { Remove-Item -Path "$(DEST_DIR)/$(DEV_ZIP)" -Force }'
	$(PS) 'if (Test-Path "$(DEST_DIR)/$(REL_ZIP)") { Remove-Item -Path "$(DEST_DIR)/$(REL_ZIP)" -Force }'
ifneq ($(MS_STORE_SOURCE_DIR),)
	$(PS) 'if (Test-Path "$(MS_STORE_SOURCE_DIR)/$(DEV_ZIP)") { Remove-Item -Path "$(MS_STORE_SOURCE_DIR)/$(DEV_ZIP)" -Force }'
	$(PS) 'if (Test-Path "$(MS_STORE_SOURCE_DIR)/$(REL_ZIP)") { Remove-Item -Path "$(MS_STORE_SOURCE_DIR)/$(REL_ZIP)" -Force }'
endif
