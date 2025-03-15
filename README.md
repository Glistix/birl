![birl](https://raw.githubusercontent.com/glistix/birl/main/banner.png)

[![Package Version](https://img.shields.io/hexpm/v/glistix_birl)](https://hex.pm/packages/glistix_birl)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/glistix_birl/)
[![Nix-compatible](https://img.shields.io/badge/target-nix-5277C3)](https://github.com/glistix/glistix)

# glistix-birl

**Mirrors:** [**GitHub**](https://github.com/Glistix/birl) | [**Codeberg**](https://codeberg.org/Glistix/birl)

[Glistix](https://github.com/glistix/glistix) fork of [`birl`](https://github.com/massivefermion/birl), a Date/Time handling library for Gleam.

Adds **support for the Nix target.** For that, implements the algorithms at [http://howardhinnant.github.io/date_algorithms.html](http://howardhinnant.github.io/date_algorithms.html).

Its documentation can be found at <https://hexdocs.pm/glistix_birl>.

> [!WARNING]
>
> **Disclaimer:** This is an **unofficial** fork of `birl` and we are not affiliated with its authors. If you are not using Glistix with the Nix target, consider using the original [`birl`](https://hex.pm/packages/birl) package directly instead.

## <img width=32 src="https://raw.githubusercontent.com/massivefermion/birl/main/icon.png"> Notes

Due to purity constraints, **the Nix target cannot access the local timezone of the system.**
However, **it can access the current time, but only outside pure-eval mode** (otherwise it's
assumed to be Jan 1, 1970, or 0 in Unix time). Do note, however, that accessing the current time
**can only be done once per evaluation** (later calls to `now()` always return the same result).

Otherwise, the functions and algorithms should work just fine (just try not to depend on the
current time).

## <img width=32 src="https://raw.githubusercontent.com/massivefermion/birl/main/icon.png"> Quick start

```sh
nix develop   # Optional: Enter a shell with glistix
glistix run   # Run the project
glistix test  # Run the tests
```

## <img width=32 src="https://raw.githubusercontent.com/massivefermion/birl/main/icon.png"> Installation

## Installation

_For the most recent instructions, please see [the Glistix handbook](https://glistix.github.io/book/recipes/overriding-packages.html)._

You can use this fork by running `glistix add birl` followed by adding the line below to your Glistix project's `gleam.toml` file (as of Glistix v0.7.0):

```toml
[glistix.preview.patch]
# ... Existing patches ...
# Add this line:
birl = { name = "glistix_birl", version = ">= 1.0.0 and < 2.0.0" }
```

This ensures transitive dependencies on `birl` will also use the patch.

Keep in mind that patches only have an effect on end users' projects - they are ignored when publishing a package to Hex, so end users are responsible for any patches their dependencies may need.

If your project or package is only meant for the Nix target, you can also use this fork in `[dependencies]` directly through `glistix add glistix_birl` in order to not rely on patching. However, the patch above is still going to be necessary for end users to fix other dependencies which depend on `birl`.

## <img width=32 src="https://raw.githubusercontent.com/massivefermion/birl/main/icon.png"> Usage

```gleam
import birl
import birl/duration

pub fn main() {
    let now = birl.now()
    let two_weeks_later = birl.add(now, duration.weeks(2))
    birl.to_iso8601(two_weeks_later)
}
```
