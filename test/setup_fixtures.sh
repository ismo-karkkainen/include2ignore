#!/bin/sh
set -e

# Get absolute paths for reliability
WORKSPACE_DIR=$(pwd)
FIXTURE_DIR="$WORKSPACE_DIR/test/fixtures/search_test_dir"
EXTRA_DIR="$WORKSPACE_DIR/test/fixtures/extra_stuff"
LINK_DIR="$WORKSPACE_DIR/test/fixtures/link_test_dir"

echo "Cleaning up old fixtures..."
rm -rf "$WORKSPACE_DIR/test/fixtures"
mkdir -p "$FIXTURE_DIR"
mkdir -p "$EXTRA_DIR"

echo "Creating normal files and directories..."
touch "$FIXTURE_DIR/regular_file.txt"
mkdir -p "$FIXTURE_DIR/subdir"
touch "$FIXTURE_DIR/subdir/subdir_file.txt"
mkdir -p "$FIXTURE_DIR/dir_a"
touch "$FIXTURE_DIR/dir_a/file_a.txt"
mkdir -p "$FIXTURE_DIR/dir_b"
touch "$FIXTURE_DIR/dir_b/file_b.txt"

echo "Creating symlinks..."
# Case 1: Symlink to a file
ln -s "subdir/subdir_file.txt" "$FIXTURE_DIR/symlink_to_file"

# Case 2: Symlink to parent directory
ln -s ".." "$FIXTURE_DIR/subdir/symlink_to_parent"

# Case 3: Two directories with symlinks to each other's parent directories
# Note: symlinks are relative to the directory they're in.
ln -s "../dir_b" "$FIXTURE_DIR/dir_a/link_to_dir_b"
ln -s "../dir_a" "$FIXTURE_DIR/dir_b/link_to_dir_a"

echo "Fixture directory created at ${FIXTURE_DIR}"

# Case 4: Symlink outside the basedir
mkdir -p "$EXTRA_DIR"
touch "$EXTRA_DIR/hidden.txt"
# The target is ../extra_stuff relative to $FIXTURE_DIR
ln -s "../extra_stuff" "$FIXTURE_DIR/outside_symlink"

(
mkdir -p ${LINK_DIR}
cd ${LINK_DIR}
mkdir -p subdir/dir_a
touch subdir/dir_a/file_a1.txt
touch subdir/dir_a/file_a2.txt
touch subdir/dir_a/file_a3.md
touch subdir/dir_a/file_a4.md
ln -s file_a2.txt subdir/dir_a/file_a5.txt
mkdir -p subdir/dir_b subdir/dir_i subdir/dir_e
touch subdir/dir_b/file_b1.txt
touch subdir/dir_b/file_b2.txt
touch subdir/dir_b/file_b3.md
touch subdir/dir_b/file_b4.md
touch subdir/dir_i/file_b1.txt
touch subdir/dir_i/file_b3.md
touch subdir/dir_e/file_b2.txt
touch subdir/dir_e/file_b4.md
ln -s subdir sbdr
mkdir -p sd/dir_c
touch sd/dir_c/file_c1.txt
touch sd/dir_c/file_c2.txt
touch sd/dir_c/file_c3.md
touch sd/dir_c/file_c4.md
ln -s ../subdir/dir_a sd/dir_a
ln -s ../subdir/dir_c sd/dir_b
ln -s dir_b subdir/dir_c
ln -s ../../subdir/dir_a/file_a5.txt sd/dir_c/file_c5.txt
ln -s loop_1 loop_2
ln -s loop_2 loop_1
ln -s not-found broken
)
echo "Fixture directory created at ${LINK_DIR}"
