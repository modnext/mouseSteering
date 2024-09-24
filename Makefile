# Variables
GAME_NAME = FarmingSimulator2022
MOD_NAME = FS22_mouseSteering

FILE_NAMES = modDesc.xml icon_mouseSteering.dds
FOLDER_NAMES = src l10n data

SOURCE_DIR = C:/Mods/$(GAME_NAME)/$(MOD_NAME)
DEST_DIR = C:/Mods/$(GAME_NAME)

# Targets
.PHONY: dev build clean

# Development build
dev:
	cd $(SOURCE_DIR)
	zip -r $(MOD_NAME)_dev.zip $(FILE_NAMES) $(FOLDER_NAMES)
	powershell -Command "Move-Item -Path $(MOD_NAME)_dev.zip -Destination $(DEST_DIR) -Force"

# Production build
build:
	cd $(SOURCE_DIR)
	zip -r $(MOD_NAME).zip $(FILE_NAMES) $(FOLDER_NAMES)
	powershell -Command "Move-Item -Path $(MOD_NAME).zip -Destination $(DEST_DIR) -Force"

# Clean up build files
clean:
	powershell -Command "Remove-Item -Path \"$(DEST_DIR)/$(MOD_NAME)_dev.zip\" -Force -ErrorAction SilentlyContinue"
	powershell -Command "Remove-Item -Path \"$(DEST_DIR)/$(MOD_NAME).zip\" -Force -ErrorAction SilentlyContinue"