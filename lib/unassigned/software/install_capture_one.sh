#!/bin/bash
# Fleet passes the PKG path via $INSTALLER_PATH
# This just runs the PKG, which contains the real install logic as postinstall script
installer -pkg "$INSTALLER_PATH" -target /
defaults write com.apple.dock persistent-apps -array-add '<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>/Applications/Capture One.app</string><key>_CFURLStringType</key><integer>0</integer></dict><key>file-label</key><string>Capture One</string></dict><key>tile-type</key><string>file-tile</string></dict>'
killall Dock