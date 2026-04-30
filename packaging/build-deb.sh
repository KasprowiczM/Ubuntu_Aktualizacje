#!/usr/bin/env bash
# =============================================================================
# packaging/build-deb.sh — Stage repo into packaging/deb/opt/... and build .deb
#
# Output: dist/<package>_<version>_all.deb (package name read from DEBIAN/control)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PKG_DIR="${SCRIPT_DIR}/packaging/deb"
STAGE="${PKG_DIR}/opt/ubuntu-aktualizacje"
DIST="${SCRIPT_DIR}/dist"

VERSION=$(awk -F'[ :]+' '/^Version:/{print $2; exit}' "${PKG_DIR}/DEBIAN/control")
[[ -z "$VERSION" ]] && { echo "cannot read Version from control"; exit 1; }
# Match the binary Package: name (Package field, not Source) so the .deb
# filename matches what `dpkg -l` will show after install. Avoids confusion
# like "ubuntu-aktualizacje_0.3.0_all.deb" containing Package: ascendo.
PKG_NAME=$(awk -F'[ :]+' '/^Package:/{print $2; exit}' "${PKG_DIR}/DEBIAN/control")
[[ -z "$PKG_NAME" ]] && { echo "cannot read Package from control"; exit 1; }

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
chmod 0755 "${PKG_DIR}/usr/bin/ubuntu-aktualizacje" \
           "${PKG_DIR}/usr/bin/ascendo-launch"

OUT="${DIST}/${PKG_NAME}_${VERSION}_all.deb"
echo "── Building $OUT"
( cd "${PKG_DIR}/.." && dpkg-deb --build --root-owner-group deb "$OUT" )
# Clean up any older mismatched filename so `ls dist/` is unambiguous.
find "${DIST}" -maxdepth 1 -name 'ubuntu-aktualizacje_*_all.deb' \
    ! -name "$(basename "$OUT")" -delete 2>/dev/null || true
echo "✔ ${OUT}"
echo "   install with: sudo dpkg -i ${OUT}"
