#!/bin/bash

# Build Oliver and Boris from source (local checkout or GitHub main)
# into $DIST/helpers/ so `make app` and Xcode can bundle them into
# BANAL.app/Contents/Helpers/.
#
# Source lookups: explicit override, sibling checkout, ~/t3/zig/<name>,
# or cloned from https://github.com/drawmeanelephant/<name>.git (branch: main)
# into .build/helpers-src/<name>.
# Missing checkout/compiler = skip with a note, never fatal — BANAL degrades
# gracefully without a bundled engine. Cross-compilation failure falls back to
# a host-arch binary.
#
# Set HELPERS_STRICT=1 to invert that: a missing, unbuildable, non-executable,
# or non-universal helper is a hard failure with a loud annotation and a
# nonzero exit. CI uses strict mode so a bundle shipping without working
# engines can never look green. Local development keeps the lenient default,
# because a laptop with no Zig and no network must still be able to build and
# use local notes.
#
# Usage: Scripts/helpers.sh [dist-dir]

set -u

DIST="${1:-dist}"
HELPERS="$DIST/helpers"
ZIG="${ZIG:-zig}"
CACHE_DIR="${HELPERS_CACHE_DIR:-.build/helpers-src}"
STRICT="${HELPERS_STRICT:-0}"

# Engines that did not make it in. Populated in both modes; only fatal in strict.
FAILURES=()

warn() {
	echo "warning: $*" >&2
}

# Loud, unmissable failure. GitHub Actions renders ::error:: as a red
# annotation; elsewhere the same text goes to stderr.
fail() {
	# Always recorded; only shouted about under strict mode. In lenient mode
	# the specific warning() lines already said what went wrong, and a local
	# build with no Zig should not look like a build failure.
	if is_strict; then
		echo "" >&2
		echo "════════════════════════════════════════════════════════════" >&2
		echo "  HELPER BUILD FAILURE: $*" >&2
		echo "════════════════════════════════════════════════════════════" >&2
		if [ "${GITHUB_ACTIONS:-}" = "true" ]; then
			echo "::error title=Helper build failed::$*" >&2
		fi
	fi
	FAILURES+=("$*")
}

is_strict() {
	case "$(printf '%s' "$STRICT" | tr '[:upper:]' '[:lower:]')" in
	1 | true | yes | on) return 0 ;;
	*) return 1 ;;
	esac
}

# Confirm what we actually shipped: present, executable, and universal. The
# host-arch fallback path produces a thin binary, so this is also what catches
# a silent cross-compile regression.
verify_helper() {
	local name="$1"
	local bin="$HELPERS/$name"
	[ -f "$bin" ] || {
		warn "$name: no binary at $bin"
		return 1
	}
	[ -x "$bin" ] || {
		warn "$name: $bin is not executable"
		return 1
	}
	local archs
	archs="$(lipo -archs "$bin" 2>/dev/null || true)"
	case "$archs" in
	*x86_64*arm64* | *arm64*x86_64*)
		echo "helpers: verified $name (universal: $archs)"
		return 0
		;;
	*)
		warn "$name: not universal (architectures: ${archs:-unknown})"
		return 1
		;;
	esac
}

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
		if ! verify_helper "$tool"; then
			fail "$tool did not produce a verified universal binary in $HELPERS"
		fi
	else
		warn "no $tool source found — bundling without it"
		fail "$tool source not found (looked in \$OLIVER_DIR/\$BORIS_DIR, sibling checkouts, $CACHE_DIR, and github.com/drawmeanelephant/$tool)"
	fi
done

# Lenient by default: a laptop with no Zig and no network still gets a local
# build, because local notes must work with no engines present. Strict mode
# turns the collected failures into a build failure.
if [ "${#FAILURES[@]}" -gt 0 ]; then
	if is_strict; then
		echo "" >&2
		echo "HELPERS_STRICT=1: ${#FAILURES[@]} engine(s) unusable. Failing the build." >&2
		echo "Set HELPERS_STRICT=0 to build without bundled engines (local, offline)." >&2
		exit 1
	fi
	warn "${#FAILURES[@]} engine(s) unavailable; continuing because HELPERS_STRICT=${STRICT}."
	warn "The app will fall back to the builtin compiler / PATH engines. Run with HELPERS_STRICT=1 to make this fatal."
fi

exit 0
