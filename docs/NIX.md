# Vocalinux Nix Flake & Maintenance Guide

This document details how to install, run, configure, and maintain Vocalinux using Nix Flakes directly from the GitHub repository (`dkchw/vocalinux`), as well as how to clean up local development builds and speech models.

---

## 1. Installing with Nix Flake

You can install or run Vocalinux without cloning the repository or manually managing Python virtual environments.

### Option A: User Profile Installation (`nix profile`)

Installs the `vocalinux` binary and desktop entry into your current user environment:

```bash
# Before merging PR #1 (from the feature branch):
nix profile install github:dkchw/vocalinux/feature/nix-flake-german

# After merging into main:
nix profile install github:dkchw/vocalinux
```

Verify the installation:
```bash
vocalinux --version
# Output: vocalinux 0.17.0
```

Start Vocalinux:
```bash
vocalinux --debug
```

To update to the latest revision at any time:
```bash
nix profile upgrade vocalinux
```

---

### Option B: Ephemeral Execution (`nix run`)

Run Vocalinux directly without permanently installing it to your profile:

```bash
# Before merging PR #1:
nix run github:dkchw/vocalinux/feature/nix-flake-german -- --debug

# After merging into main:
nix run github:dkchw/vocalinux -- --debug
```

You can pass any standard Vocalinux arguments after `--`:
```bash
# Example: Launch directly with German language and German model
nix run github:dkchw/vocalinux -- --language de --model tiny.de
```

---

### Option C: System-Wide Configuration (NixOS Flake)

To include Vocalinux as part of your system packages in your `/etc/nixos/flake.nix`:

```nix
{
  description = "NixOS configuration with Vocalinux";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    vocalinux = {
      url = "github:dkchw/vocalinux"; # or "github:dkchw/vocalinux/feature/nix-flake-german"
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, vocalinux, ... }: {
    nixosConfigurations.your-hostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ({ pkgs, ... }: {
          environment.systemPackages = [
            vocalinux.packages.${pkgs.system}.default
          ];
        })
      ];
    };
  };
}
```

---

### Option D: Home Manager Flake

If you manage your dotfiles and user packages with Home Manager:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    vocalinux.url = "github:dkchw/vocalinux";
  };

  outputs = { self, nixpkgs, home-manager, vocalinux, ... }: {
    homeConfigurations."your-username" = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      modules = [
        {
          home.packages = [
            vocalinux.packages.x86_64-linux.default
          ];
        }
      ];
    };
  };
}
```

---

## 2. Using the German Whisper Model

Vocalinux supports the German fine-tuned Whisper model (`primeline/whisper-tiny-german`) via `whisper.cpp` (`ggml-tiny-de.bin`).

### Via Graphical Settings Dialog
1. Open **Settings** from the tray menu.
2. In the **Language** dropdown, select **German** (`de`).
   - The engine automatically resolves to the `tiny.de` model specialization (**German (primeline)**).
3. Alternatively, expand **Advanced → Speech Engine**:
   - Set **Model size** to **Tiny**.
   - Under **Specialization**, choose **German (primeline)** (`75 MB`).
4. Click **Apply** or let auto-apply download the verified model file.

### Via Command-Line Interface
```bash
# Specify the canonical ID:
vocalinux --language de --model tiny.de

# Or specify the Hugging Face model repository alias:
vocalinux --language de --model primeline/whisper-tiny-german
```

---

## 3. Removing Downloaded Models

Vocalinux provides multiple ways to delete models and free disk space:

### In the Settings GUI
- **Active Model**: When viewing any downloaded model in the Settings card, click the red **"Delete model from disk"** button. The app will confirm, safely unload the model from memory, and delete the file.
- **Unused Models**: Expand the **"Unused downloads"** section at the bottom of the Speech Engine page. Each unused model displays its size and an individual **Delete** button.

### In the Terminal
Use the `--delete-model` flag to remove models without opening the GUI:
```bash
# Delete by canonical ID:
vocalinux --delete-model tiny.de

# Delete by Hugging Face alias:
vocalinux --delete-model primeline/whisper-tiny-german
```

---

## 4. Removing Development Builds & Cleaning Up

### 1. Remove Local `result` Symlink
If you compiled the application locally using `nix build`:
```bash
rm -f result
```

### 2. Remove Profile Installation
If you installed Vocalinux into your user profile via `nix profile`:
```bash
# List installed profile packages
nix profile list

# Remove vocalinux by package name:
nix profile remove vocalinux

# Or remove by index number (if index 0):
nix profile remove 0
```

### 3. Reclaim Nix Store Disk Space
To purge unreferenced builds and old generations from `/nix/store`:
```bash
nix-collect-garbage -d
```

### 4. Remove Old Python Virtual Environments
If you previously used `install.sh` or pip/uv:
```bash
# Inside the repository directory:
rm -rf .venv venv build dist *.egg-info
```

### 5. Clear Downloaded Models Directory
To completely remove all speech models downloaded to disk:
```bash
rm -rf ~/.local/share/vocalinux/models/
```
