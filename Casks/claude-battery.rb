cask "claude-battery" do
  version "0.1.3"
  sha256 "bc51b8a93479df03274d84c6c3ae87880050d15cf98f79bb0fdc89e0113a8553"

  url "https://github.com/allthingsclaude/battery/releases/download/v0.1.3/Battery-0.1.3.dmg"
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
