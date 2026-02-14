cask "claude-battery" do
  version "0.2.2"
  sha256 "b87520b87733e3e2654b3f256315afdaa32c7739f6ec7b5fe57f3b8a02854842"

  url "https://github.com/allthingsclaude/battery/releases/download/v0.2.2/Battery-0.2.2.dmg"
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
