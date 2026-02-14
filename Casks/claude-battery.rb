cask "claude-battery" do
  version "0.2.6"
  sha256 "277e2ec34593b7295a28744099e3f5fcc2fde2bcfaa6b1cbff0436f9fb578824"

  url "https://github.com/allthingsclaude/battery/releases/download/v0.2.6/Battery-0.2.6.dmg"
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
