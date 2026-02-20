cask "claude-battery" do
  version "0.2.12"
  sha256 "709de7e569112d5a235978b24469a8275ba8403c4af4b60598ce79555f1b748e"

  url "https://github.com/allthingsclaude/battery/releases/download/v0.2.12/Battery-0.2.12.dmg"
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
