# DevSound X
A complete rewrite of DevSound for Game Boy. Unfortunately, it is incompatible with previous versions of DevSound, but it makes up for it with new features and significantly reduced CPU load.

## Building the source code

### General dependencies

1. [RGBDS](https://github.com/gbdev/rgbds)
2. An emulator of your choice (such as [BGB](https://bgb.bircd.org), [SameBoy](https://sameboy.github.io), or [Emulicious](https://emulicious.net))
- VisualBoyAdvance is not supported as it fails to correctly emulate a hardware quirk that DevSound X relies on.

### Build instructions
#### Windows
1. Clone the repo: `git clone --recursive https://github.com/DevEd2/DevSoundX`
2. Run `build.bat`.

#### Linux and macOS
1. Clone the repo: `git clone --recursive https://github.com/DevEd2/DevSoundX`
2. Run `build.sh`. If you get a "permission denied" error, run `chmod +x build.sh` and try again.

## Including DevSound X in your project
Just copy the `Audio` folder to your project's root directory and include `Audio/DevSoundX.asm` somewhere in your project.

## Using DevSound X
1. Call `DSX_Init`. This only needs to be done once (ideally during bootup).
2. Load the pointer to the song you want to play into HL and call `DSX_PlaySong`, i.e. like this: `ld hl,Mus_Foobar :: call DSX_PlaySong`
3. Call `DSX_Update` once per VBlank (or on a timer interrupt if desired).
4. If you need to stop music playback, call `DSX_StopMusic`.

## Making music for DevSound X
Unfortunately, there are currently no tools to work with DevSound X, so you'll need to program songs in manually. This repository includes [a test song](https://github.com/DevEd2/DevSoundX/blob/main/Audio/Music/TestSong.asm) as an example, and there is some documentation available [here](https://github.com/DevEd2/DevSoundX/blob/main/Docs/Format.txt).
