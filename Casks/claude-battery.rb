cask "claude-battery" do
  version "0.4.0"
  sha256 "b678842964777d97f50b35e4aefd588aa0b320887e896ed4c9a054a9578e3db0"

  url "https://github.com/allthingsclaude/battery/releases/download/v0.4.0/Battery-0.4.0.dmg"
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
