#!/usr/bin/env bash
# =============================================================================
# packaging/build-deb.sh — Stage repo into packaging/deb/opt/... and build .deb
#
# Output: dist/ubuntu-aktualizacje_<version>_all.deb
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PKG_DIR="${SCRIPT_DIR}/packaging/deb"
STAGE="${PKG_DIR}/opt/ubuntu-aktualizacje"
DIST="${SCRIPT_DIR}/dist"

VERSION=$(awk -F'[ :]+' '/^Version:/{print $2; exit}' "${PKG_DIR}/DEBIAN/control")
[[ -z "$VERSION" ]] && { echo "cannot read Version from control"; exit 1; }

echo "── Cleaning stage"
rm -rf "$STAGE"
mkdir -p "$STAGE" "$DIST"

echo "── Copying tracked files into $STAGE"
# Use git ls-files so the .deb tree mirrors the GitHub source-of-truth.
git -C "$SCRIPT_DIR" ls-files | while IFS= read -r f; do
    case "$f" in
        packaging/*) continue ;;       # don't ship packaging tree itself
        dist/*)      continue ;;
        app/tauri/*) continue ;;       # native skin built separately
        .github/*|.gitignore|*.md.example) continue ;;
    esac
    mkdir -p "$STAGE/$(dirname "$f")"
    cp -a "$SCRIPT_DIR/$f" "$STAGE/$f"
done

# Mark all .sh executable
find "$STAGE" -name '*.sh' -exec chmod +x {} +

echo "── Setting DEBIAN/* perms"
chmod 0755 "${PKG_DIR}/DEBIAN/postinst" "${PKG_DIR}/DEBIAN/prerm"
chmod 0755 "${PKG_DIR}/usr/bin/ubuntu-aktualizacje"

OUT="${DIST}/ubuntu-aktualizacje_${VERSION}_all.deb"
echo "── Building $OUT"
( cd "${PKG_DIR}/.." && dpkg-deb --build --root-owner-group deb "$OUT" )
echo "✔ ${OUT}"
