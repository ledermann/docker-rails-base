#!/usr/bin/env bash
# Compare two Ruby Alpine images and print the differences as Markdown.
#
# Usage: base-image-diff.sh OLD_IMAGE NEW_IMAGE
# Set PLATFORM to inspect another platform (default: linux/amd64).
set -euo pipefail

old_ref="$1"
new_ref="$2"
platform="${PLATFORM:-linux/amd64}"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

export LC_ALL=C

# Writes "<name>.sys" (component versions) and "<name>.pkg" (apk packages),
# both as tab-separated "key<TAB>value" lines. The container prints both
# lists, separated by a "--" line.
probe() {
  local ref="$1" name="$2"
  docker run --rm -i --quiet --platform "$platform" "$ref" sh -es <<'EOF' |
printf 'Alpine\t%s\n' "$(cat /etc/alpine-release)"
ruby -e 'puts "Ruby\t#{RUBY_VERSION} (#{RUBY_REVISION[0, 10]})"
         puts "RubyGems\t#{Gem::VERSION}"
         require "bundler"
         puts "Bundler\t#{Bundler::VERSION}"'
echo '--'
# Skip virtual packages like ".ruby-rundeps", their version is a timestamp
awk -F: '/^P:/ { p = $2 } /^V:/ && p !~ /^\./ { print p "\t" $2 }' /lib/apk/db/installed
EOF
    awk -v sys="$tmp/$name.sys" -v pkg="$tmp/$name.pkg" \
      '/^--$/ { f = 1; next } { print > (f ? pkg : sys) }'
}

# Short form of an image reference: "ruby:4.0.9-alpine@sha256:abcdef1..."
short() {
  sed -E 's/(@sha256:[0-9a-f]{7})[0-9a-f]+/\1/' <<< "$1"
}

# Writes "<name>.idx" with one "platform<TAB>digest" line per image in the
# index. Attestation manifests ("unknown/unknown") are skipped.
manifests() {
  local ref="$1" name="$2"
  docker buildx imagetools inspect --raw "$ref" | jq -r '
    .manifests[]?
    | select(.platform.os != "unknown")
    | [([.platform.os, .platform.architecture, .platform.variant // empty]
        | join("/")), .digest]
    | @tsv' | sort > "$tmp/$name.idx"
}

manifests "$old_ref" old
manifests "$new_ref" new

echo "### Base image: \`$(short "$old_ref")\` → \`$(short "$new_ref")\`"
echo

# A digest change can come from a rebuild of a single platform. Then the
# inspected platform is identical, and a probe would only show equal values.
if [ -s "$tmp/old.idx" ] && [ -s "$tmp/new.idx" ]; then
  changed=$(
    join -t $'\t' -a 1 -a 2 -e '–' -o 0,1.2,2.2 "$tmp/old.idx" "$tmp/new.idx" |
      awk -F'\t' '$2 != $3 { printf "%s`%s`", (n++ ? ", " : ""), $1 }'
  )
  echo "Changed platforms: ${changed:-none (only the index metadata changed)}"
  echo

  # Number of distinct digests of the inspected platform in both indexes.
  # "linux/arm64" also matches "linux/arm64/v8".
  digests=$(
    awk -F'\t' -v p="$platform" '$1 == p || index($1, p "/") == 1 { print $2 }' \
      "$tmp/old.idx" "$tmp/new.idx" | sort -u | wc -l
  )
  if [ "$digests" -eq 1 ]; then
    echo "The \`$platform\` image is identical. Nothing to compare."
    exit 0
  fi
fi

probe "$old_ref" old
probe "$new_ref" new

echo "| Component | Old | New |"
echo "|---|---|---|"
paste "$tmp/old.sys" "$tmp/new.sys" | awk -F'\t' '{
  new = ($2 == $4) ? $4 : "**" $4 "**"
  print "| " $1 " | " $2 " | " new " |"
}'
echo

join -t $'\t' -a 1 -a 2 -e '–' -o 0,1.2,2.2 \
  <(sort "$tmp/old.pkg") <(sort "$tmp/new.pkg") | awk -F'\t' '
  $2 != $3 {
    if (!n++) print "| Changed apk package | Old | New |\n|---|---|---|"
    print "| " $1 " | " $2 " | " $3 " |"
  }
  END { if (!n) print "No apk package changes." }'
echo
echo "<sub>Inspected on \`$platform\`.</sub>"
