cask "claude-battery" do
  version "0.1.0"
  sha256 "c78a798dfe25cc5e1fbc6c75c0d75964426fac216649075d0c692c8e0624f78d"

  url "https://github.com/allthingsclaude/battery/releases/download/v0.1.0/Battery-0.1.0.dmg"
  name "Battery"
  desc "Claude Code usage monitor for your menu bar"
  homepage "https://github.com/allthingsclaude/battery"

  app "Battery.app"
  binary "#{appdir}/Battery.app/Contents/MacOS/Battery", target: "claude-battery"

  zap trash: [
    "~/Library/Preferences/com.allthingsclaude.battery.plist",
    "~/.battery",
  ]
end
