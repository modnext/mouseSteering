## Config
MOD_NAME = FS25_mouseSteering

## Package contents
FILES  = modDesc.xml icon_mouseSteering.dds
DIRS   = src l10n data
PKG    = $(FILES) $(DIRS)

## Paths
SOURCE_DIR = $(CURDIR)
DEST_DIR   = $(patsubst %/,%,$(dir $(CURDIR)))

## Artifacts
DEV_ZIP = $(MOD_NAME)_dev.zip
REL_ZIP = $(MOD_NAME).zip

## Tools
PS  = powershell -NoProfile -ExecutionPolicy Bypass -Command
ZIP = tar -a -c -f

.PHONY: all dev build clean

all: build

## Build dev zip and copy to game Mods folder
dev:
	cd "$(SOURCE_DIR)" && $(ZIP) "$(DEV_ZIP)" $(PKG)
	$(PS) "Move-Item -Path \"$(SOURCE_DIR)/$(DEV_ZIP)\" -Destination \"$(DEST_DIR)\" -Force"

## Build release zip and move to dist folder
build:
	cd "$(SOURCE_DIR)" && $(ZIP) "$(REL_ZIP)" $(PKG)
	$(PS) "Move-Item -Path \"$(SOURCE_DIR)/$(REL_ZIP)\" -Destination \"$(DEST_DIR)\" -Force"

## Remove dev and release artifacts
clean:
	$(PS) 'if (Test-Path "$(DEST_DIR)/$(DEV_ZIP)") { Remove-Item -Path "$(DEST_DIR)/$(DEV_ZIP)" -Force }'
	$(PS) 'if (Test-Path "$(DEST_DIR)/$(REL_ZIP)") { Remove-Item -Path "$(DEST_DIR)/$(REL_ZIP)" -Force }'
