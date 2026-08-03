#!/bin/sh
set -eu

defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false

defaults write NSGlobalDomain com.apple.mouse.scaling -float 1.0
defaults write NSGlobalDomain com.apple.mouse.linear -bool true

defaults -currentHost write NSGlobalDomain com.apple.keyboard.modifiermapping.13364-4704-0 -array \
	'<dict><key>HIDKeyboardModifierMappingSrc</key><integer>30064771298</integer><key>HIDKeyboardModifierMappingDst</key><integer>30064771299</integer></dict>' \
	'<dict><key>HIDKeyboardModifierMappingSrc</key><integer>30064771299</integer><key>HIDKeyboardModifierMappingDst</key><integer>30064771298</integer></dict>' \
	'<dict><key>HIDKeyboardModifierMappingSrc</key><integer>30064771302</integer><key>HIDKeyboardModifierMappingDst</key><integer>30064771303</integer></dict>' \
	'<dict><key>HIDKeyboardModifierMappingSrc</key><integer>30064771303</integer><key>HIDKeyboardModifierMappingDst</key><integer>30064771302</integer></dict>'

defaults write com.apple.HIToolbox AppleFnUsageType -int 0
defaults write com.apple.HIToolbox AppleDictationAutoEnable -int 0

defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

defaults write com.apple.WindowManager EnableStandardClickToShowDesktop -bool false

defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock show-recents -bool false
defaults write com.apple.dock appswitcher-all-displays -bool true

defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true

defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 28 '<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>51</integer><integer>20</integer><integer>1441792</integer></array><key>type</key><string>standard</string></dict></dict>'
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 29 '<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>51</integer><integer>20</integer><integer>1179648</integer></array><key>type</key><string>standard</string></dict></dict>'
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 30 '<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>52</integer><integer>21</integer><integer>1441792</integer></array><key>type</key><string>standard</string></dict></dict>'
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 31 '<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>52</integer><integer>21</integer><integer>1179648</integer></array><key>type</key><string>standard</string></dict></dict>'
/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u

defaults write com.knollsoft.Rectangle launchOnLogin -bool true

killall Finder Dock 2>/dev/null || true

echo "Done. Some keyboard settings take effect after logging out and back in."
