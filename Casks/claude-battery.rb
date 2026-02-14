cask "claude-battery" do
  version "0.2.3"
  sha256 "c75aecaa2337c2e98dcb4e055a865c707443cffbad7c3051dfb0eb12c107c737"

  url "https://github.com/allthingsclaude/battery/releases/download/v0.2.3/Battery-0.2.3.dmg"
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
