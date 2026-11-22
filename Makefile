# Wrapper so that `make` works from PowerShell / Windows Terminal.
# GNU make runs recipes with cmd.exe here (no sh on PATH).
.PHONY: all build help
all: build

build:
	cmd /c .\make.bat

help:
	@echo make        - build teletext-slojd.ssd (runs make.bat; listing in compile.txt)
	@echo make help   - this list
	@echo run.bat launches B-em with teletext-slojd.ssd.
