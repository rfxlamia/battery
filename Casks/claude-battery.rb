cask "claude-battery" do
  version "0.2.11"
  sha256 "4b1798a48961d364d8e0b16f18ee16f7f1b7957005720259c78f892107ae4b48"

  url "https://github.com/allthingsclaude/battery/releases/download/v0.2.11/Battery-0.2.11.dmg"
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
