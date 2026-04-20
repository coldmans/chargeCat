cask "charge-cat" do
  version "1.0.1"
  sha256 "dfadb2ff19c302d5d34568f0901c827c1d9a16b7d8e3bc09656b8964b4ecb48b"

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
