#!/bin/sh
# One-time setup for a fresh clone (re-run it any time; it is safe).
#
# Xcode rewrites String Catalogs (*.xcstrings) in its own JSON format, while
# scripts write ordinary JSON, which made the catalogs look changed before
# every push. This builds scripts/xcstrings-format.swift and installs it as a git
# filter, then puts both catalogs in that one format on disk and in git, so an
# Xcode rewrite is the same file and nothing shows as changed.
#
#   sh scripts/setup-git.sh
set -e
root="$(git rev-parse --show-toplevel)"
cd "$root"
bin="$(git rev-parse --absolute-git-dir)/xcstrings-format"

swiftc -O scripts/xcstrings-format.swift -o "$bin"

git config filter.xcstrings.clean "\"$bin\""
git config filter.xcstrings.smudge cat
# Without the tool (another machine, no Xcode) git stores the file as is.
git config filter.xcstrings.required false

for catalog in $(git ls-files '*.xcstrings'); do
    "$bin" < "$catalog" > "$catalog.tmp" && mv "$catalog.tmp" "$catalog"
done
git add --renormalize -- '*.xcstrings'
echo "String Catalog filter installed. Commit the catalogs if they show as changed."
