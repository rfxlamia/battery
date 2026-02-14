cask "claude-battery" do
  version "0.2.5"
  sha256 "06520108e18a4e51a219179c105eaf0b30c0e6f3afdd1c3107c55041cbf679ba"

  url "https://github.com/allthingsclaude/battery/releases/download/v0.2.5/Battery-0.2.5.dmg"
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
