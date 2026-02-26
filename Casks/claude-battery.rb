cask "claude-battery" do
  version "0.3.1"
  sha256 "3010982806229d983952862f29164f426025d8a62bfcccd1092b5a9d49461923"

  url "https://github.com/allthingsclaude/battery/releases/download/v0.3.1/Battery-0.3.1.dmg"
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
