# Spec Delta

## Purpose

Defines how the confined Limusic Snap interacts with the desktop: audio,
media keys, tray, local files, networking, and the features that cannot work
under strict confinement.

## ADDED Requirements

### Requirement: Audio playback through libmpv

The Snap MUST play audio through the system-provided libmpv runtime and the
`audio-playback` interface.

#### Scenario: Playback starts

- **WHEN** the user starts a track
- **THEN** libmpv opens the default PulseAudio or PipeWire output inside the
  Snap's confinement
- **AND** audio is audible on the host

#### Scenario: libmpv version is sufficient

- **WHEN** the Snap is built on Ubuntu 24.04
- **THEN** the staged `libmpv2` is version 0.37 (the noble package), which
  satisfies upstream's documented minimum of mpv 0.35

### Requirement: MPRIS player identity

The Snap MUST expose an MPRIS player named `org.mpris.MediaPlayer2.limusic` and
MUST allow desktop media controls to operate it.

#### Scenario: Media keys control playback

- **WHEN** the user presses play/pause, next, or previous on the keyboard or in
  the desktop media widget
- **THEN** the running Limusic instance receives the MPRIS command and acts on
  it
- **AND** the player's metadata and playback state are visible to the desktop

#### Scenario: Slot name matches upstream

- **WHEN** the `mpris` slot is declared
- **THEN** it sets `name: limusic`, matching the `dbus_name` used by upstream's
  `souvlaki` configuration

### Requirement: Tray integration

The Snap MUST provide a StatusNotifierItem tray icon when the desktop exposes a
StatusNotifierWatcher.

#### Scenario: Tray appears on a supported desktop

- **WHEN** the app starts on a desktop with a StatusNotifierWatcher
- **THEN** the tray icon is registered through the `desktop` interface
- **AND** the tray menu can show the window, control playback, and quit

#### Scenario: No unnecessary appindicator library

- **WHEN** the Snap is staged
- **THEN** it does not stage `libayatana-appindicator`, because upstream's Linux
  tray uses `ksni` and the binary does not link against that library

### Requirement: Local music access

The Snap MUST be able to read local music files chosen by the user.

#### Scenario: Music under the home directory

- **WHEN** the user adds a track from a non-hidden directory under their home
- **THEN** the app can read and play it through the `home` interface

#### Scenario: Music on removable media

- **WHEN** the user has connected the `removable-media` interface and adds a
  track from a mounted removable volume
- **THEN** the app can read and play it

### Requirement: Network access and loopback proxy

The Snap MUST be allowed to reach the internet and to bind its local video
proxy.

#### Scenario: Streaming and API calls

- **WHEN** the app loads YouTube Music content or calls its APIs
- **THEN** outbound network access is allowed by the `network` interface

#### Scenario: Loopback video proxy

- **WHEN** the app starts its local HTTP proxy for music videos
- **THEN** binding the loopback port is allowed by the `network-bind` interface

### Requirement: Discord Rich Presence limitation

The Snap MUST fail soft when Discord Rich Presence cannot connect, and the
limitation MUST be documented.

#### Scenario: Discord is running on the host

- **WHEN** the app tries to connect to Discord's local IPC socket
- **THEN** the connection is not possible because strict confinement gives the
  Snap its own `XDG_RUNTIME_DIR` and snapd has no interface for Discord IPC
- **AND** the app continues to run normally without Rich Presence

### Requirement: Single-instance limitation

The Snap MUST avoid relying on D-Bus name ownership for single-instance
behavior, because strict confinement does not grant that name.

#### Scenario: Second launch

- **WHEN** the user launches the app while an instance is already running
- **THEN** the app starts normally rather than failing on a denied D-Bus name
- **AND** the limitation is documented, including the `LIMUSIC_MULTI`
  environment variable used to skip the single-instance plugin

### Requirement: Autostart limitation

The Snap MUST NOT claim that start-on-login works when the host autostart
directory is outside its confinement.

#### Scenario: User enables start-on-login

- **WHEN** the user enables the setting
- **THEN** the app may write an autostart entry inside its own snap data
  directory
- **AND** the documentation states that the host desktop will not read it under
  strict confinement

### Requirement: Least-privilege interfaces

The Snap MUST declare only the interfaces needed for its documented behavior.

#### Scenario: Interface review

- **WHEN** the snap's plugs and slots are reviewed
- **THEN** the only explicitly declared plugs are `network`, `network-bind`,
  `audio-playback`, `home` and `removable-media`
- **AND** desktop, GPU, display and settings interfaces come from the GNOME
  extension rather than being duplicated by hand
- **AND** no interface is added for Discord IPC or host autostart, because no
  such interface exists
