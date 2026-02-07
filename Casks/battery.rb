cask "battery" do
  version "0.1.0"
  sha256 "9c1ae92c188f9697cae74a465ef8081975e2850a77d52b8d11e38df0aab98230"

  url "https://github.com/allthingsclaude/battery/releases/download/v0.1.0/Battery-0.1.0.dmg"
  name "Battery"
  desc "Claude Code usage monitor for your menu bar"
  homepage "https://github.com/allthingsclaude/battery"

  app "Battery.app"

  zap trash: [
    "~/Library/Preferences/com.allthingsclaude.battery.plist",
    "~/.battery",
  ]
end
