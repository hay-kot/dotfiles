#!/usr/bin/env bash

# Set Zed as the default for common text and config file types.
# Uses infat: https://github.com/philocalyst/infat

# Broad plain-text type coverage
infat set Zed --type plain-text

# Config / data formats
infat set Zed --ext json
infat set Zed --ext yaml
infat set Zed --ext yml
infat set Zed --ext toml
infat set Zed --ext xml
infat set Zed --ext csv
infat set Zed --ext env

# Markup / docs
infat set Zed --ext md
infat set Zed --ext txt
infat set Zed --ext log

# Web
infat set Zed --ext html
infat set Zed --ext css
infat set Zed --ext js
infat set Zed --ext ts

# Shell
infat set Zed --ext sh

echo "defaults: done!"
