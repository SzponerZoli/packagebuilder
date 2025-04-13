#!/bin/bash
set -e

echo "=== SzponerZoli's Automated Package Builder Script ==="

# Folder selection
read -p "Choose working directory (default: current directory): " WORK_DIR
if [[ -z "$WORK_DIR" ]]; then
    WORK_DIR="$(pwd)"
elif [[ ! -d "$WORK_DIR" ]]; then
    echo "Error: Directory '$WORK_DIR' does not exist."
    exit 1
fi
cd "$WORK_DIR"
echo "Working in: $WORK_DIR"

# Define available licenses and categories
LICENSES=(
    "GPL-2.0"
    "GPL-3.0"
    "MIT"
    "Apache-2.0"
    "BSD-3-Clause"
    "LGPL-2.1"
    "LGPL-3.0"
)

CATEGORIES=(
    "AudioVideo"
    "Development"
    "Education"
    "Game"
    "Graphics"
    "Network"
    "Office"
    "Science"
    "Settings"
    "System"
    "Utility"
)

read -p "Binary name (e.g., davintux-converter): " BIN_NAME
if [[ -z "$BIN_NAME" ]]; then
    echo "Error: Binary name cannot be empty."
    exit 1
fi
if [[ ! -f "$BIN_NAME" ]]; then
    echo "Error: Binary file '$BIN_NAME' not found."
    exit 1
fi
if [[ ! -x "$BIN_NAME" ]]; then
    echo "Error: Binary file '$BIN_NAME' is not executable."
    exit 1
fi

read -p "Package name (e.g., davintux-converter): " PACKAGE_NAME
if [[ -z "$PACKAGE_NAME" ]]; then
    echo "Error: Package name cannot be empty."
    exit 1
fi
if [[ ! "$PACKAGE_NAME" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
    echo "Error: Package name must be lowercase and can only contain letters, numbers, and hyphens."
    exit 1
fi

read -p "Program name (e.g., Davintux Converter): " PROGRAM_NAME
if [[ -z "$PROGRAM_NAME" ]]; then
    echo "Error: Program name cannot be empty."
    exit 1
fi

read -p "Version (e.g., 1.0): " VERSION
if [[ -z "$VERSION" ]]; then
    echo "Error: Version cannot be empty."
    exit 1
fi
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+$ ]]; then
    echo "Error: Version must be in the format X.Y (e.g., 1.0)."
    exit 1
fi

read -p "Icon file name (e.g., davintux.png): " ICON_FILE
read -p "Description: " DESCRIPTION
read -p "Maintainer (e.g., Zoli <szponerzolidev@proton.me>): " MAINTAINER
read -p "Is this a graphical application? (y/n): " IS_GUI

echo "Available licenses:"
for i in "${!LICENSES[@]}"; do
    echo "[$i] ${LICENSES[$i]}"
done
read -p "Select license number: " LICENSE_NUM
if [[ ! "$LICENSE_NUM" =~ ^[0-9]+$ ]] || [ "$LICENSE_NUM" -ge "${#LICENSES[@]}" ]; then
    echo "Error: Invalid license selection."
    exit 1
fi
LICENSE="${LICENSES[$LICENSE_NUM]}"

echo "Available categories:"
for i in "${!CATEGORIES[@]}"; do
    echo "[$i] ${CATEGORIES[$i]}"
done
read -p "Select category number (default: Utility): " CATEGORY_NUM
if [[ -z "$CATEGORY_NUM" ]]; then
    CATEGORY="Utility"
elif [[ ! "$CATEGORY_NUM" =~ ^[0-9]+$ ]] || [ "$CATEGORY_NUM" -ge "${#CATEGORIES[@]}" ]; then
    echo "Error: Invalid category selection."
    exit 1
else
    CATEGORY="${CATEGORIES[$CATEGORY_NUM]}"
fi

if [[ "$IS_GUI" =~ ^[Yy]$ ]]; then
    TERMINAL=false
else
    TERMINAL=true
fi

PKG_DIR="${BIN_NAME}_${VERSION}"
rm -rf "$PKG_DIR"
mkdir -p "$PKG_DIR/DEBIAN"
mkdir -p "$PKG_DIR/usr/bin"
mkdir -p "$PKG_DIR/usr/share/applications"
mkdir -p "$PKG_DIR/usr/share/icons/hicolor/128x128/apps"

cp "$BIN_NAME" "$PKG_DIR/usr/bin/"
cp "$ICON_FILE" "$PKG_DIR/usr/share/icons/hicolor/128x128/apps/${BIN_NAME}.png"

# Improved dependency handling
DEPS=$(ldd "$BIN_NAME" | grep "=>" | awk '{print $1}' | grep '^lib' | sed 's/\.so\.[0-9.]*$//' | sed 's/^lib//' | sort -u | tr '\n' ',' | sed 's/,$//' | sed 's/\([^,]*\)/lib\1/g')

if [[ -z "$DEPS" ]]; then
    DEPS="libc6"
else
    DEPS="libc6, $DEPS"
fi

cat <<EOF > "$PKG_DIR/DEBIAN/control"
Package: $PACKAGE_NAME
Version: $VERSION
Section: utils
Priority: optional
Architecture: amd64
Depends: $DEPS
Maintainer: $MAINTAINER
Description: $DESCRIPTION
License: $LICENSE
EOF

cat <<EOF > "$PKG_DIR/usr/share/applications/${BIN_NAME}.desktop"
[Desktop Entry]
Type=Application
Name=$PROGRAM_NAME
Comment=$DESCRIPTION
Exec=$BIN_NAME
Icon=$BIN_NAME
Terminal=$TERMINAL
Categories=$CATEGORY;
EOF

chmod 755 "$PKG_DIR/usr/bin/$BIN_NAME"
chmod 644 "$PKG_DIR/usr/share/applications/${BIN_NAME}.desktop"
chmod 644 "$PKG_DIR/usr/share/icons/hicolor/128x128/apps/${BIN_NAME}.png"
chmod 644 "$PKG_DIR/DEBIAN/control"

# Build DEB package
echo "Building Debian package..."
dpkg-deb --root-owner-group --build "$PKG_DIR"
DEB_FILE="${BIN_NAME}_${VERSION}.deb"
if [ -f "${PKG_DIR}.deb" ] && [ "${PKG_DIR}.deb" != "$DEB_FILE" ]; then
    mv "${PKG_DIR}.deb" "$DEB_FILE"
fi
echo "Created Debian package: $DEB_FILE"

# Convert to RPM if alien is available
if command -v alien >/dev/null 2>&1; then
    echo "Converting to RPM package..."
    sudo alien --to-rpm --scripts "$DEB_FILE" || {
        echo "Error: RPM conversion failed"
        exit 1
    }
    echo "Created RPM package: ${BIN_NAME}-${VERSION}-2.x86_64.rpm"
else
    echo "Warning: 'alien' not found. Skipping RPM creation."
    echo "Install with: sudo apt-get install alien"
fi

# Convert to Arch Linux package if debtap is available
if command -v debtap >/dev/null 2>&1; then
    echo "Converting to Arch Linux package..."
    sudo debtap -u
    sudo debtap "$DEB_FILE"
    echo "Created Arch Linux package: ${PACKAGE_NAME}-${VERSION}-1-x86_64.tar.zst"
else
    echo "Warning: 'debtap' not found. Skipping Arch Linux package creation."
    echo "Install with: yay -S debtap"
fi

echo "Package creation completed!"