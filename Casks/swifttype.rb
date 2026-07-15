cask "swifttype" do
  version "1.0.4"
  sha256 :no_check

  url "https://github.com/VariableThe/SwiftType/releases/download/v#{version}/SwiftType.zip"
  name "SwiftType"
  desc "Fast, local, intelligent, system-wide autocorrect for macOS"
  homepage "https://github.com/VariableThe/SwiftType"

  depends_on macos: :ventura

  app "SwiftType.app"

  postflight do
    # Clear macOS quarantine attribute so Gatekeeper allows running the locally/CI-built application without warning
    system_command "xattr",
                   args: ["-cr", "#{appdir}/SwiftType.app"],
                   sudo: false
  end

  uninstall quit: "com.swifttype.app"

  zap trash: [
    "~/Library/Application Support/SwiftType",
    "~/Library/Preferences/com.swifttype.app.plist",
  ]
end
