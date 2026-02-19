cask "claude-battery" do
  version "0.2.8"
  sha256 "5b90d9dc12db7866a7946692d596cfe02f6cc5adee0c74d38dd79545324e03db"

  url "https://github.com/allthingsclaude/battery/releases/download/v0.2.8/Battery-0.2.8.dmg"
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
