<div align="center">

# Clothesline

**A tiny, tactile home for screenshots, photos, and files on your Mac.**

[Download](https://github.com/MiWang0608/Clothesline/releases/latest) · [简体中文](README.md) · [Report an issue](https://github.com/MiWang0608/Clothesline/issues)

<img src="docs/images/hero.png" alt="A native macOS clothesline with polaroids, a translucent file pocket, and a kraft-paper folder" width="100%">

</div>

A little rope lives at the top-right of your screen. Hover over the knot and it drops down, holding your recent screenshots and the files you want close at hand. Move away and it folds back up.

Built with **Swift + AppKit**, with no third-party package dependencies. Lives in the menu bar, without a Dock icon.

- Automatically collects new screenshots, with a fly-in animation.
- Accepts photos, documents, and folders dragged from Finder.
- Click to Quick Look; double-click to open; drag out to use elsewhere.
- Polaroids keep their original aspect ratio. Documents get translucent pockets; folders get kraft envelopes.
- Spring motion, little wooden clips, paper textures, and a quiet footprint.

<div align="center">
<img src="docs/images/demo.gif" alt="Native-rendered demo of the rope expanding, swaying, and retracting" width="960">
</div>

*Images use the app's actual card/rope drawing code and spring calculations, with generated demo content and a presentation background. They are not captures of a private desktop. The animation illustrates expansion/retraction; try the app for screenshot fly-in and other interactions.*

## Run without development tools

Requires **macOS 13+**. Xcode and the Swift development toolchain are not required for the prebuilt executable.

1. Download from [Releases](https://github.com/MiWang0608/Clothesline/releases/latest): **arm64** for Apple Silicon (M-series), **x86_64** for Intel.
2. Unzip. In Terminal, type `cd `, drag the extracted folder into Terminal, and press Return.
3. Run:

   ```bash
   ./Clothesline
   ```

Keep Terminal open. Hover over the knot at the top-right. Allow Desktop access if prompted for automatic screenshot collection. Quit using the menu-bar paperclip or `Ctrl-C`.

**First launch:** this personal project is ad-hoc signed, not Developer ID signed or notarized. If macOS blocks it, verify the download source and follow [Apple's instructions](https://support.apple.com/102445) to allow it in System Settings → Privacy & Security. Do not disable Gatekeeper globally or override a malware warning.

## Your files

- **Screenshots and dropped images are moved** into `~/Library/Application Support/Clothesline/Images/`. If moving fails, the app attempts to copy instead.
- Other documents and folders stay in their original locations; the app keeps a reference.
- Dragged-out photos remain available for at least 24 hours and are cleaned up on a later launch. Removing a photo from the context menu moves it to Trash. Removing a document only removes its reference.
- Processing is local. The project contains no network request code.

## Current limits

- Appears on the primary display only.
- Automatic screenshots arrive after the system thumbnail disappears and the file is saved, usually around five seconds.
- File-promise drags without a real file URL are not supported; drag from Finder instead.
- Launch at login requires an `.app` bundle and is unavailable in this terminal release.
- Early personal project; UI behavior needs further testing across Macs. Intel is cross-compiled, not tested on physical Intel hardware.

## Build and contribute

Development requires macOS 13+ and a Swift 5.9+ toolchain.

```bash
git clone https://github.com/MiWang0608/Clothesline.git
cd Clothesline
swift run Clothesline
swift test
```

All 22 core tests passed on macOS before this release. Tests cover storage, references, delayed cleanup, screenshot recognition, and directory monitoring; UI behavior is not covered by automated tests.

```bash
scripts/package-release.sh 0.1.0  # package both Mac architectures
scripts/render-preview.sh        # regenerate native preview assets, without reading user files
```

[Detailed guide (Chinese)](docs/guide.zh-CN.md) · [Issues](https://github.com/MiWang0608/Clothesline/issues) · [MIT License](LICENSE)
