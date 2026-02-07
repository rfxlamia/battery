cask "claude-battery" do
  version "0.1.0"
  sha256 "fe41e817d228557feba0a23b80082525bc056af81a2865b4dce9d91051eade92"

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
