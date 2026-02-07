cask "battery" do
  version "0.1.0"
  sha256 "PLACEHOLDER"

  url "https://github.com/allthingsclaude/battery/releases/download/v#{version}/Battery-#{version}.dmg"
  name "Battery"
  desc "Claude Code usage monitor for your menu bar"
  homepage "https://github.com/allthingsclaude/battery"

  app "Battery.app"

  zap trash: [
    "~/Library/Preferences/com.allthingsclaude.battery.plist",
    "~/.battery",
  ]
end
