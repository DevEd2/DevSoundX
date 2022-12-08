# DevSound X
A complete rewrite of DevSound for Game Boy. Unfortunately, it is incompatible with previous versions of DevSound, but it makes up for it with new features and significantly reduced CPU load.

## Building the source code

### General dependencies

1. [RGBDS](https://github.com/gbdev/rgbds)
2. An emulator of your choice (such as [BGB](https://bgb.bircd.org), [SameBoy](https://sameboy.github.io), or [Emulicious](https://emulicious.net))
- VisualBoyAdvance is not supported as it fails to correctly emulate a hardware quirk that DevSound X relies on.

### Build instructions
1. Clone the repo: `git clone --recursive https://github.com/DevEd2/DevSoundX`
2. Run build.sh (if you get a permission denied error, run `chmod +x build.sh` and try again)

## Including DevSound X in your project
TODO
