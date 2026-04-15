cask "charge-cat" do
  version "1.0.0"
  sha256 "0aaa9e212edf71173f41302ccc949c07f88e33f3e519b68516bd49e0ec20197f"

  url "https://github.com/coldmans/chargeCat/releases/download/v#{version}/ChargeCat-#{version}.dmg"
  name "Charge Cat"
  desc "A tiny cat greets you from a little door every time you plug in your charger"
  homepage "https://coldmans.github.io/chargeCat/"

  depends_on macos: ">= :sonoma"

  app "Charge Cat.app"

  zap trash: [
    "~/Library/Preferences/com.coldmans.charge-cat.plist",
    "~/Library/Saved Application State/com.coldmans.charge-cat.savedState",
  ]
end
