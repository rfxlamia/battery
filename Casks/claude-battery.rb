cask "claude-battery" do
  version "0.3.0"
  sha256 "e729e1c6ac711077e450bab89f973d981081e85bfed951061aec427e0326e198"

  url "https://github.com/allthingsclaude/battery/releases/download/v0.3.0/Battery-0.3.0.dmg"
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
