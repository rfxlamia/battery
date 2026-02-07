cask "claude-battery" do
  version "0.1.0"
  sha256 "e1f8d8c8665a07094ebc1676439495a3c80834b76f8ed87e14df1467d508f3a0"

  url "https://github.com/allthingsclaude/battery/releases/download/v0.1.0/Battery-0.1.0.dmg"
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
