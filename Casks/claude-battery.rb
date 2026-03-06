cask "claude-battery" do
  version "0.3.4"
  sha256 "8c3966ce9218a7eff0d0214ca09fa03c7784e376f3314703fc76e8444161f29c"

  url "https://github.com/allthingsclaude/battery/releases/download/v0.3.4/Battery-0.3.4.dmg"
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
