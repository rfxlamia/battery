cask "claude-battery" do
  version "0.2.0"
  sha256 "01b47a130a3f9a696e673c6521a06b44ef5708596cca531256873d989e203ecd"

  url "https://github.com/allthingsclaude/battery/releases/download/v0.2.0/Battery-0.2.0.dmg"
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
