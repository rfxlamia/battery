cask "claude-battery" do
  version "0.2.5"
  sha256 "fc78894e3e63056e4daf3966b188a65253692a18067acdcbebd67a73408bb87d"

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
