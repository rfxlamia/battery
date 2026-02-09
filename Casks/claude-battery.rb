cask "claude-battery" do
  version "0.1.3"
  sha256 "84a32bbf9dc5572ffa1dd3e986e6fa0693fd213ac2cbb10f95ae1d4d642b2131"

  url "https://github.com/allthingsclaude/battery/releases/download/v0.1.3/Battery-0.1.3.dmg"
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
