cask "claude-battery" do
  version "0.1.0"
  sha256 "98278abad1ed9686fc067d1581f83d1b1de9c016b5ea11e3a89b575d6762a6e0"

  url "https://github.com/allthingsclaude/battery/releases/download/v0.1.0/Battery-0.1.0.dmg"
  name "Battery"
  desc "Claude Code usage monitor for your menu bar"
  homepage "https://github.com/allthingsclaude/battery"

  app "Battery.app"
  binary "#{appdir}/Battery.app/Contents/MacOS/Battery", target: "claude-battery"

  zap trash: [
    "~/Library/Preferences/com.allthingsclaude.battery.plist",
    "~/.battery",
  ]
end
