# Homebrew Cask Submission Prep

Last updated: 2026-04-20

This document tracks what Charge Cat still needs before it has a realistic chance of being accepted into the official [`Homebrew/homebrew-cask`](https://github.com/Homebrew/homebrew-cask) repository.

## Relevant Homebrew docs

- [Acceptable Casks](https://docs.brew.sh/Acceptable-Casks)
- [Adding Software to Homebrew](https://docs.brew.sh/Adding-Software-to-Homebrew)
- [How to Create and Maintain a Tap](https://docs.brew.sh/How-to-Create-and-Maintain-a-Tap)

## Current status

### Good

- A cask already exists at [Casks/charge-cat.rb](/Users/coldmans/Documents/GitHub/chargeCat/Casks/charge-cat.rb)
- The release asset URL pattern is stable:
  - `https://github.com/coldmans/chargeCat/releases/download/v#{version}/ChargeCat-#{version}.dmg`
- The cask now includes:
  - `verified:` for the GitHub release URL
  - `livecheck` using `:github_latest`
  - `depends_on macos: ">= :sonoma"`

### Blocking

1. The GitHub Release is not published yet.
   - Local check on 2026-04-20: `gh release view v1.0.1` returned `release not found`
   - Official casks need a real downloadable upstream release artifact.

2. Gatekeeper readiness is not there yet.
   - Local check on 2026-04-20:
     - `codesign -dv dist/ChargeCat-1.0.1.dmg` -> `code object is not signed at all`
     - `spctl -a -vv '/Volumes/.../Charge Cat.app'` -> `rejected`
   - Homebrew docs explicitly call out apps that fail with Gatekeeper enabled as unacceptable, and unsigned apps are specifically mentioned.

3. Self-submitted popularity is far below the documented threshold.
   - Local check on 2026-04-20 using GitHub CLI:
     - stars: `0`
     - watchers: `0`
     - forks: `0`
   - Homebrew's current docs say self-submitted casks face higher thresholds, with rejection possible under `225 stars`, `90 watchers`, and `90 forks`.

## Practical recommendation

For now, keep using the project tap or a dedicated `homebrew-chargecat` tap. Official `homebrew/cask` submission does not look realistic until the signing and popularity problems are solved.

## What must happen before submission

1. Publish a real GitHub Release for `v1.0.1` or newer with the DMG attached.
2. Sign the `.app` with a real Apple Developer ID Application certificate.
3. Notarize the app and ship a notarized DMG.
4. Confirm Gatekeeper accepts the installed app on a clean Apple Silicon Mac.
5. Re-check repository popularity against the current Homebrew thresholds.
6. Only then prepare the upstream PR.

## Suggested validation commands

After publishing a signed + notarized release:

```bash
gh release view v1.0.1
spctl -a -vv -t open dist/ChargeCat-1.0.1.dmg
brew install --cask ./Casks/charge-cat.rb
brew uninstall --cask charge-cat
```

Inside a local clone of `homebrew/homebrew-cask`, Homebrew's docs recommend:

```bash
brew audit --new --cask charge-cat
brew style --fix charge-cat
```

## Expected upstream cask shape

Charge Cat is already close to the expected shape:

```ruby
cask "charge-cat" do
  version "1.0.1"
  sha256 "..."

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
```

## Submission decision

As of 2026-04-20: do not submit to `homebrew/cask` yet.

Use this checklist again after:

- Developer ID signing
- notarization
- a published GitHub Release
- higher GitHub adoption
