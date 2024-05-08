#!/bin/bash

pacman -Syyu
pacman -S --noconfirm brightnessctl iw power-profiles-daemon powertop redshift
