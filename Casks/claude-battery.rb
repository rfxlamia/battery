cask "claude-battery" do
  version "0.2.10"
  sha256 "9266df5d27efb09792daf33610bdf8417e5d2b84301721f52986ea97343d4a50"

  url "https://github.com/allthingsclaude/battery/releases/download/v0.2.10/Battery-0.2.10.dmg"
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
