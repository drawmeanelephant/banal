#!/bin/bash

# Build Oliver and Boris from source (local checkout or GitHub main)
# into $DIST/helpers/ so `make app` and Xcode can bundle them into
# BANAL.app/Contents/Helpers/.
#
# Source lookups: explicit override, sibling checkout, ~/t3/zig/<name>,
# or cloned from https://github.com/drawmeanelephant/<name>.git (branch: main)
# into .build/helpers-src/<name>.
# Missing checkout/compiler = skip with a note, never fatal — BANAL degrades
# gracefully without a bundled engine.
# Cross-compilation failure falls back to a host-arch binary.
#
# Usage: Scripts/helpers.sh [dist-dir]

set -u

DIST="${1:-dist}"
HELPERS="$DIST/helpers"
ZIG="${ZIG:-zig}"
CACHE_DIR="${HELPERS_CACHE_DIR:-.build/helpers-src}"

mkdir -p "$HELPERS"

find_or_fetch_source() {
	local name="$1" override="${2:-}"
	# 1. Explicit override
	if [ -n "$override" ] && [ -d "$override" ] && { [ -f "$override/build.zig.zon" ] || [ -f "$override/build.zig" ]; }; then
		printf '%s' "$override"
		return 0
	fi

	# 2. Sibling and local candidate checkouts
	for candidate in "../$name" "../../$name" "../$name/main" "$HOME/t3/zig/$name"; do
		if [ -n "$candidate" ] && [ -d "$candidate" ] && { [ -f "$candidate/build.zig.zon" ] || [ -f "$candidate/build.zig" ]; }; then
			printf '%s' "$candidate"
			return 0
		fi
	done

	# 3. Cached clone or fetch from GitHub main
	local cached="$CACHE_DIR/$name"
	if [ -d "$cached" ] && { [ -f "$cached/build.zig.zon" ] || [ -f "$cached/build.zig" ]; }; then
		if [ -d "$cached/.git" ]; then
			git -C "$cached" pull --ff-only origin main >/dev/null 2>&1 || true
		fi
		printf '%s' "$cached"
		return 0
	fi

	# 4. Clone from remote GitHub repository main branch
	mkdir -p "$CACHE_DIR"
	echo "helpers: fetching $name from https://github.com/drawmeanelephant/$name.git..." >&2
	if git clone --depth 1 https://github.com/drawmeanelephant/$name.git "$cached" >/dev/null 2>&1; then
		if [ -d "$cached" ] && { [ -f "$cached/build.zig.zon" ] || [ -f "$cached/build.zig" ]; }; then
			printf '%s' "$cached"
			return 0
		fi
	fi

	return 1
}

build_helper() {
	local name="$1" src="$2"
	local tmp arm x86

	if ! command -v "$ZIG" >/dev/null 2>&1; then
		echo "warning: zig compiler ('$ZIG') not found — cannot build $name helper" >&2
		return 1
	fi

	tmp="$(mktemp -d)"
	arm="$tmp/arm64"
	x86="$tmp/x86_64"

	echo "helpers: compiling universal $name from $src..."
	if (cd "$src" && "$ZIG" build --prefix "$arm" -Doptimize=ReleaseSafe -Dtarget=aarch64-macos) &&
		(cd "$src" && "$ZIG" build --prefix "$x86" -Doptimize=ReleaseSafe -Dtarget=x86_64-macos); then
		if [ -f "$arm/bin/$name" ] && [ -f "$x86/bin/$name" ] && lipo -create "$arm/bin/$name" "$x86/bin/$name" -output "$HELPERS/$name.tmp" 2>/dev/null; then
			mv "$HELPERS/$name.tmp" "$HELPERS/$name"
			chmod +x "$HELPERS/$name"
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
		chmod +x "$HELPERS/$name"
		rm -rf "$tmp"
		echo "helpers: built host-arch $name from $src"
		return 0
	else
		rm -rf "$tmp"
		echo "warning: could not build $name from $src — bundling without it" >&2
		rm -f "$HELPERS/$name"
		return 1
	fi
}

for tool in oliver boris; do
	case "$tool" in
	oliver) src_override="${OLIVER_DIR:-}" ;;
	boris) src_override="${BORIS_DIR:-}" ;;
	esac
	if src="$(find_or_fetch_source "$tool" "$src_override")"; then
		build_helper "$tool" "$src"
	else
		echo "warning: no $tool source found — bundling without it" >&2
	fi
done

exit 0
