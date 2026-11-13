# Kios - iOS 12 for Android

iOS 12 in an Android app, on a stock phone: no root, locked bootloader, no Termux. iOS 12 can be
installed on the phone itself from Apple's servers. The companion of Kios for Windows.

Research preview. Tested on a Galaxy S25 Ultra (Snapdragon 8 Elite, 12 GB RAM); iOS 12 also on a
Galaxy A71 and a Galaxy M31 (much slower: their CPUs cannot run iOS's code natively, see below).

## Which phones

Nothing in it is specific to the S25 Ultra; it is the phone it is developed and measured on.

| | Needs | Recommended |
|---|---|---|
| iOS 12 | 64-bit Android 10 or later, 4 GB RAM | ARMv8.2-A or later (iOS's code runs natively), 6 GB RAM or more |
| Room | iOS 12 about 3 GB; more while installing from Apple (below) | |

- Without the ARMv8.2 features below, iOS still runs, all of it emulated, several times slower.
- Speed is mostly the CPU's big cores: an older or smaller core is slower whatever its ARM version.
- RAM: iOS 12 reached its lock screen on a 4 GB phone with about 1 GB left to Android; with less
  to spare, Android may close it. iOS 12's memory is fixed at 2 GiB for the guest.
- Free memory for iOS (home screen, Settings): while iOS runs, the background processes of other
  apps are ended every 90 s, so Android does not close iOS for lack of memory. Android 14 and later
  let an app end only its own, so there the app asks adb's shell on the phone itself (`am kill-all`)
  over Wireless debugging: pair once (Settings on the home screen > Wireless debugging; the code from
  Developer options goes into a notification of the app). Wireless debugging needs Wi-Fi and is off
  again after a restart of the phone until it is turned on.

## What works

- iOS 12 full screen, touch, iOS's own keyboard, Safari with HTTPS pages.
- Side bar (right edge): tap its handle to show or hide the buttons, drag it to move the bar up or
  down; it stays where you leave it. Home, the side button, a touch lock (touches stop reaching iOS),
  pin (Android's screen pinning: the phone's edge swipes no longer pull down the notification shade
  or go home over iOS), saves. A long press on a button says what it does.
- The phone's volume keys are iOS's (held, they repeat). Android's back gesture is iOS's edge swipe.
  Turning the phone's screen off locks iOS too.
- Quick boot: swiping the app away, or Save and close, keeps iOS as it is; it comes back in about
  10 s instead of a boot of a few minutes. Named saves can be taken and loaded.
- Turn off (in 💾, or the notification) shuts iOS down without a save; the next start boots. The
  last quick save stays as a way back: Go back, on the home screen or in 💾, returns to it with the
  memory it was saved with, until the next Save and close replaces it.
- Settings and apps you add stay on the phone's own copy of the disk.

Not working: App Store and Apple ID, audio, GPU acceleration (it draws on the CPU).

## Setting it up from Apple (no PC)

Set up builds iOS 12 on the phone itself from Apple's files: no PC, no adb.

- It downloads only the parts of Apple's iOS 12 IPSW the disk is made of, straight from Apple's
  servers: several connections, pieces written in place, each part checked against the IPSW's own
  CRC-32. It picks the fastest of Apple's servers, goes on after an app kill, a restart or a lost
  network, can wait for Wi-Fi, and has Pause and Cancel on its notification.
- Then a helper VM runs in the app's QEMU: it makes the kernel with the iPhone's device tree and
  builds the iOS disk from the downloaded images. The disk is packed and set up like one brought
  from a PC, then iOS is started once until its lock screen and saved, so your first start takes
  seconds.
- It needs about 10 GB free at its height (with less, the downloaded files go as soon as the disk
  no longer needs them) and leaves about 3 GB: the disk and iOS's own data with its save. Keep the
  phone on its charger.

The app and this repository hold no Apple file: what is built comes from Apple's servers on the phone.

## Building

- QEMU and `qemu-img`: built in Termux on the phone (`-D__TERMUX__ -O2 -fno-emulated-tls`).
  `pull-libs.sh` copies them (as `libqemu.so`, `libqemuimg.so`) and their Termux libraries into
  `app/src/main/jniLibs`.
- The setup from Apple: `pull-setup.sh [checkout]` copies the helper VM (`Image.gz`,
  `initrd.gz`; `Image16k.gz` from `$KERNEL16K`, built with `setup/helper-kernel16k.config`), the
  iOS 12 kernel, the tools that make `payload.bin` and `kios-setup.json` (the member and step list
  the installers share), and for iOS 26 and watchOS the Windows installers' Linux step bodies and
  scripts into `app/src/main/assets`.
- The app: `./gradlew assembleDebug` (Android Studio's JDK, SDK 36, NDK 29). A release build is
  signed when `~/.android/kios-release.properties` (or `$KIOS_SIGNING`) names a key.
- Tests and measurements on a phone over adb: `dev/` (`dev/test-*.sh`; input goes to the phone only
  while the app is on top and the phone is unlocked).

## Licenses

The app's code: GPL v3 (LICENSE). The APK also carries:

- QEMU 11.1 (GPL v2).
- reims-vgpu and metal2vulkan (GPL v2 or later, or LGPL v3 or later).
- Mesa's Turnip Vulkan driver (MIT) and the Khronos Vulkan loader (Apache 2.0).
- For the setup from Apple: our XNU kernel for iOS 12 (Apple Public Source License 2.0; built from
  Apple's XNU with patches), and the Windows installer's helper VM (`installer/helper`): Linux 6.12
  (GPL v2; kernel.org's 6.12.114 with `installer/helper/kernel.config`, and for the phone's engine
  also `setup/helper-kernel16k.config` here), Ubuntu 24.04 arm64 packages under their own licenses
  (sources at https://launchpad.net/ubuntu), and apfs-fuse (GPL v2).
- Termux packages QEMU links (GLib, GnuTLS, Nettle, libslirp, pixman, zstd and others, under their
  own licenses).
- Conscrypt (Apache 2.0): TLS 1.3 for the pairing with Wireless debugging. The adb client itself
  (`Adb*.java`, `Spake2.java`) is the app's own, written after AOSP's adb (Apache 2.0); SPAKE2's two
  points are BoringSSL's.

Not affiliated with Apple. iOS is Apple's.