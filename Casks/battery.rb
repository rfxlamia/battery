cask "battery" do
  version "0.1.0"
  sha256 "db9706c037281dd998ac591dc1233533509a17f94b314f2a5de778c6ca9c0aab"

  url "https://github.com/allthingsclaude/battery/releases/download/v0.1.0/Battery-0.1.0.dmg"
  name "Battery"
  desc "Claude Code usage monitor for your menu bar"
  homepage "https://github.com/allthingsclaude/battery"

  app "Battery.app"

  zap trash: [
    "~/Library/Preferences/com.allthingsclaude.battery.plist",
    "~/.battery",
  ]
end
