cask "claude-battery" do
  version "0.2.0"
  sha256 "1ce8ad75c0c8bde1adc1fb6b7803edb6b00b48661824da688a70690467fdec65"

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
