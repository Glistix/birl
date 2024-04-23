![birl](https://raw.githubusercontent.com/massivefermion/birl/main/banner.png)

[![Package Version](https://img.shields.io/hexpm/v/birl)](https://hex.pm/packages/birl)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/birl/)

# birl

Glistix fork of [`birl`](https://github.com/massivefermion/birl), a Date/Time handling library for Gleam.

Adds **support for the Nix target.**

Its documentation can be found at <https://hexdocs.pm/birl>.

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

Currently, you will need to **add this package as a local dependency to a Git submodule**
in your project.

You can do so following steps similar to [`glistix/stdlib`](https://github.com/glistix/stdlib).

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
