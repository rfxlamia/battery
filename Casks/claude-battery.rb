cask "claude-battery" do
  version "0.2.7"
  sha256 "98d93eed95a75db64afe26e227cb089ba45ddf976090c738eb1a2f98f51df893"

  url "https://github.com/allthingsclaude/battery/releases/download/v0.2.7/Battery-0.2.7.dmg"
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
