# Singularity

**A modular, customizable desktop environment built around Hyprland and Quickshell.**

Singularity is a Linux desktop customization project designed to provide a cohesive, consistent, and personalized desktop experience.

Built on top of Hyprland and Quickshell, it combines window management, desktop components, theming, automation, and system integrations into a unified environment.

The project focuses on modularity, visual consistency, and user control, while maintaining a desktop-oriented workflow rather than turning the desktop into a mobile-style interface.

> **Status:** Active development. Features, configurations, and installation procedures are still evolving.

## Overview

Singularity aims to create a desktop environment where every component feels like part of the same system.

Its design philosophy is based on a few principles:

- **Modularity:** Components should be independent and easy to maintain.
- **Consistency:** Themes, colors, icons, and interface elements should follow a unified visual language.
- **User control:** Users should retain control over their configurations and workflows.
- **Keyboard-first workflow:** Prioritize efficient interaction and avoid unnecessary interface elements.
- **Hardware flexibility:** Support different machines and display configurations without tying the entire environment to a single device.
- **Separation of concerns:** Keep shared system resources, user configurations, and generated state separate.

## Core Components

### Hyprland

[Hyprland](https://hypr.land/) is the foundation of Singularity's window management.

The configuration is organized into modules to keep settings structured and maintainable.

### Quickshell

[Quickshell](https://quickshell.org/) powers the desktop interface and interactive components.

Current interface components include:

- **Status Bar:** A top panel with workspaces, media information, clock, notifications, system tray, battery, audio, network, and other indicators.
- **Contextual Applets:** Indicators and popups that appear when relevant, keeping the interface clean.
- **OSD:** On-screen feedback for system controls and input/output events.
- **Desktop Components:** Additional interface elements integrated into the overall desktop experience.

### Theming System

Singularity includes a centralized theme management system.

Themes define the visual identity of the desktop, including colors and generated configuration files.

Available themes:

- Igris
- Ion
- Lunar
- Nebula
- Solarius
- Veridian

The theme system generates user-specific configuration files inside the XDG state directory.

### Wallpaper Management

Wallpaper management is integrated into the Singularity command-line interface.

It supports selecting wallpapers, listing available options, and navigating between them.

### GTK Integration

GTK themes, icon themes, and cursor themes are included to maintain visual consistency across applications.

The project uses system-wide shared resources while allowing individual users to select their preferred appearance.

## Architecture

Singularity separates its files into three main categories:

| Category | Location | Purpose |
|---|---|---|
| Shared resources | `/usr/share/singularity` | System-wide project resources |
| User configuration | `~/.config` | Individual application configurations |
| Generated state | `~/.local/state/singularity` | User-specific generated files and state |

This separation allows multiple users to share the same installation without sharing their generated configurations.

The original repository remains independent from the installed system resources, allowing development to continue without modifying the installed copy.

## Project Structure

```text
Singularity/
├── bin/
│   ├── lib/
│   ├── singularity
│   └── ...
├── hypr/
│   ├── modules/
│   ├── hyprland.lua
│   └── hypridle.conf
├── kitty/
├── quickshell/
│   ├── components/
│   ├── modules/
│   └── theme/
├── templates/
├── themes/
├── gtk-icons/
├── gtk-themes/
└── packaging/
    ├── bin/
    └── install.sh
```

## Installation

Singularity is currently developed and tested primarily on Arch Linux.

### Requirements

- Arch Linux
- Hyprland
- Quickshell
- Bash
- Python 3
- Git
- `sudo`

Additional applications and utilities may be required depending on the enabled components.

Singularity does not currently install all external dependencies automatically. Make sure the required applications are installed before using the corresponding components.

### Clone the repository

```bash
git clone https://github.com/YOUR_USERNAME/Singularity.git
cd Singularity
```

### Run the installer

```bash
bash packaging/install.sh
```

The installer configures shared resources, global commands, GTK resources, and user configuration links.

It does not automatically install external dependencies or select hardware-specific configurations.

### Generate a theme

After installation, generate your preferred theme:

```bash
singularity theme set nebula
```

Replace `nebula` with any available theme.

## CLI

Singularity provides a command-line interface for managing themes and wallpapers.

### Themes

```bash
singularity theme list
singularity theme current
singularity theme set nebula
singularity theme next
singularity theme previous
```

### Wallpapers

```bash
singularity wallpaper list
singularity wallpaper current
singularity wallpaper set <wallpaper>
singularity wallpaper next
singularity wallpaper previous
```

## Development

Singularity is designed to evolve as a modular desktop environment.

Current development priorities include:

- Improving hardware flexibility and multi-monitor support.
- Developing machine-specific modules.
- Expanding desktop components and contextual applets.
- Refining the installation and configuration process.
- Improving consistency across applications and desktop components.

The repository is intended to remain the primary development workspace, independently from the system-wide installation.

## Contributing

Contributions, suggestions, and bug reports are welcome.

If you want to contribute, consider opening an issue to discuss significant changes before submitting a pull request.

## License

License and third-party asset attributions should be documented here before public distribution.