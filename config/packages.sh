#!/usr/bin/env bash
# Curated package choices; these are not a complete Arch repository index.
PACKAGE_RECOMMENDED=(
  base-devel git curl wget nano man-db man-pages
  networkmanager sudo
)
PACKAGE_OPTIONAL=(
  vim neovim htop btop tmux openssh rsync unzip zip
  bluez bluez-utils cups avahi
  pipewire-alsa pipewire-pulse wireplumber
  mpv firefox ffmpeg
  cargo rust gcc make cmake python python-pip
  docker docker-compose
)
