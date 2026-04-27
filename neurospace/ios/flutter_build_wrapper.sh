#!/bin/sh
# Wrapper script that strips macOS Sequoia provenance attributes
# from Flutter.framework before and after the build step.
# This fixes "resource fork, Finder information, or similar detritus not allowed"
# when the project is on an iCloud-synced folder.

# Prevent extended attrs from being copied
export COPYFILE_DISABLE=1
export COPY_EXTENDED_ATTRIBUTES_DISABLE=1

# Strip from Flutter engine cache (the SOURCE of the copy)
if [ -n "$FLUTTER_ROOT" ]; then
  find "$FLUTTER_ROOT/bin/cache/artifacts/engine" -name "Flutter" -type f -exec xattr -c {} \; 2>/dev/null
fi

# Strip from build dir
find "${BUILT_PRODUCTS_DIR}" -name "Flutter" -type f -exec xattr -c {} \; 2>/dev/null
find "${PROJECT_DIR}/../build" -name "Flutter" -type f -exec xattr -c {} \; 2>/dev/null

# Run the actual build
/bin/sh "$FLUTTER_ROOT/packages/flutter_tools/bin/xcode_backend.sh" "$@"
BUILD_RESULT=$?

# Strip after build (in case the build step re-copies)
find "${BUILT_PRODUCTS_DIR}" -name "Flutter" -type f -exec xattr -c {} \; 2>/dev/null
find "${PROJECT_DIR}/../build" -name "Flutter" -type f -exec xattr -c {} \; 2>/dev/null

exit $BUILD_RESULT
