cask "claude-battery" do
  version "0.2.9"
  sha256 "e10f5f5a8e42576271b63a718fd0d9834c9cccfbe609c92cde57ef3a95c7b4fa"

  url "https://github.com/allthingsclaude/battery/releases/download/v0.2.9/Battery-0.2.9.dmg"
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
