cask "claude-battery" do
  version "0.3.3"
  sha256 "fbfd110e36baadd38a8d814e0f0ab44f55c2c4fae93981a8090a18492d2a07a3"

  url "https://github.com/allthingsclaude/battery/releases/download/v0.3.3/Battery-0.3.3.dmg"
  name "Battery"
  desc "Claude Code usage monitor for your menu bar"
  homepage "https://github.com/allthingsclaude/battery"

  app "Battery.app"
  binary "#{appdir}/Battery.app/Contents/Resources/claude-battery"

  zap trash: [
    "~/Library/Preferences/com.allthingsclaude.battery.plist",
    "~/.battery",
  ]
end
