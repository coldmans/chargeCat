cask "charge-cat" do
  version "1.0.1"
  sha256 "e2d706ae70b51c2aed51b021c20f2dbbe05e3e5c32d8fcc0987cf8530f960678"

  url "https://github.com/coldmans/chargeCat/releases/download/v#{version}/ChargeCat-#{version}.dmg",
      verified: "github.com/coldmans/chargeCat/"
  name "Charge Cat"
  desc "A tiny cat greets you from a little door every time you plug in your charger"
  homepage "https://coldmans.github.io/chargeCat/"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :sonoma"

  app "Charge Cat.app"

  zap trash: [
    "~/Library/Preferences/com.coldmans.charge-cat.plist",
    "~/Library/Saved Application State/com.coldmans.charge-cat.savedState",
  ]
end
