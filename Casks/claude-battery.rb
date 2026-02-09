cask "claude-battery" do
  version "0.1.1"
  sha256 "5fa62033ddc75af83b2c9c9c4cbdaa4ae0f1c8c17a1eb6594683948a6a52cb72"

  url "https://github.com/allthingsclaude/battery/releases/download/v0.1.1/Battery-0.1.1.dmg"
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
