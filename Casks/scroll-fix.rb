cask "scroll-fix" do
  version :latest
  sha256 :no_check

  url "https://github.com/LKTeloeken/scroll-fix/releases/latest/download/ScrollFix.zip"
  name "ScrollFix"
  desc "Natural scrolling on the trackpad, classic scrolling on the mouse"
  homepage "https://github.com/LKTeloeken/scroll-fix"

  depends_on macos: ">= :ventura"

  app "ScrollFix.app"

  # The app is only ad-hoc signed, so Gatekeeper would block the downloaded copy.
  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/ScrollFix.app"]
  end

  uninstall quit:       "com.lkteloeken.scrollfix",
            login_item: "ScrollFix"

  zap trash: "~/Library/Preferences/com.lkteloeken.scrollfix.plist"
end
