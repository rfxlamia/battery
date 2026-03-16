cask "claude-battery" do
  version "0.3.5"
  sha256 "e2fd7b62ae6feb60f600dba84f772d5c33cbf57c091dc7f80660e652da087070"

  url "https://github.com/allthingsclaude/battery/releases/download/v0.3.5/Battery-0.3.5.dmg"
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
