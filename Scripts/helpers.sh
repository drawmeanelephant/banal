#!/bin/bash

# Build Oliver and Boris from their Zig checkouts into $DIST/helpers/
# so `make app` can bundle them into BANAL.app/Contents/Helpers/.
#
# Source lookups mirror the locators: explicit override, sibling
# checkout, then ~/t3/zig/<name>. Missing checkout = skip with a note,
# never fatal — BANAL degrades gracefully without a bundled engine.
# Cross-compilation failure falls back to a host-arch binary.
#
# Usage: Scripts/helpers.sh [dist-dir]

set -u

DIST="${1:-dist}"
HELPERS="$DIST/helpers"
ZIG="${ZIG:-zig}"

mkdir -p "$HELPERS"

find_source() {
	local name="$1" override="${2:-}"
	for candidate in "$override" "../$name" "$HOME/t3/zig/$name"; do
		[ -n "$candidate" ] && [ -f "$candidate/build.zig.zon" ] && {
			printf '%s' "$candidate"
			return 0
		}
	done
	return 1
}

build_helper() {
	local name="$1" src="$2"
	local tmp arm x86
	tmp="$(mktemp -d)"
	arm="$tmp/arm64"
	x86="$tmp/x86_64"

	if (cd "$src" && "$ZIG" build --prefix "$arm" -Doptimize=ReleaseSafe -Dtarget=aarch64-macos) &&
		(cd "$src" && "$ZIG" build --prefix "$x86" -Doptimize=ReleaseSafe -Dtarget=x86_64-macos); then
		if lipo -create "$arm/bin/$name" "$x86/bin/$name" -output "$HELPERS/$name.tmp" 2>/dev/null; then
			mv "$HELPERS/$name.tmp" "$HELPERS/$name"
			rm -rf "$tmp"
			echo "helpers: built universal $name from $src"
			return 0
		fi
	fi
	rm -rf "$tmp"

	echo "helpers: cross-compile failed for $name — trying host arch only" >&2
	tmp="$(mktemp -d)"
	if (cd "$src" && "$ZIG" build --prefix "$tmp" -Doptimize=ReleaseSafe) &&
		[ -f "$tmp/bin/$name" ]; then
		cp "$tmp/bin/$name" "$HELPERS/$name"
		rm -rf "$tmp"
		echo "helpers: built host-arch $name from $src"
	else
		rm -rf "$tmp"
		echo "warning: could not build $name from $src — bundling without it" >&2
		rm -f "$HELPERS/$name"
	fi
}

for tool in oliver boris; do
	case "$tool" in
	oliver) src_override="${OLIVER_DIR:-}" ;;
	boris) src_override="${BORIS_DIR:-}" ;;
	esac
	if src="$(find_source "$tool" "$src_override")"; then
		build_helper "$tool" "$src"
	else
		echo "warning: no $tool checkout found — bundling without it" >&2
	fi
done

exit 0
