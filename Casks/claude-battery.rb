cask "claude-battery" do
  version "0.2.3"
  sha256 "eda977f643df155ccf947703e200e8573ad336417d3b46b3538283b101d21507"

  url "https://github.com/allthingsclaude/battery/releases/download/v0.2.3/Battery-0.2.3.dmg"
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
