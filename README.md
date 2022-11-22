# DevSoundX
A complete rewrite of DevSound for Game Boy. Unfortunately, it is incompatible with previous versions of DevSound, but it makes up for it with new features and significantly reduced CPU load.

## Building the source code

### General dependencies

1. [RGBDS](https://github.com/gbdev/rgbds)
2. An emulator of your choice (such as [BGB](https://bgb.bircd.org), [SameBoy](https://sameboy.github.io), [Emulicious](https://emulicious.net))
  - VisualBoyAdvance is not supported as it fails to correctly emulate a hardware quirk that DevSound relies on

### Build instructions
1. Open a command prompt and type `bash`
2. Clone the repo: `git clone --recursive https://github.com/DevEd2/DevSoundX`
3. Run build.sh (if you get a permission denied error, run `chmod +x build.sh` and try again)

### Including DevSound X in your project
TODO
