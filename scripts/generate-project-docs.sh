#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

mkdir -p docs
refs_file=/tmp/full_field_refs.tsv
: > "$refs_file"

for f in force-app/main/default/objects/*/fields/*.field-meta.xml; do
  src_obj=$(echo "$f" | awk -F'/' '{print $(NF-2)}')
  field_file=$(basename "$f")
  field=${field_file%.field-meta.xml}
  type=$(sed -nE 's:.*<type>(Lookup|MasterDetail)</type>.*:\1:p' "$f" | head -n1)
  [ -z "$type" ] && continue
  rel=$(sed -n 's:.*<relationshipName>\(.*\)</relationshipName>.*:\1:p' "$f" | head -n1)
  req=$(sed -n 's:.*<required>\(.*\)</required>.*:\1:p' "$f" | head -n1)
  [ -z "$req" ] && req='(none)'

  while IFS= read -r ref; do
    [ -z "$ref" ] && continue
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$src_obj" "$field" "$type" "$ref" "$rel" "$req" "$f" >> "$refs_file"
  done < <(sed -n 's:.*<referenceTo>\(.*\)</referenceTo>.*:\1:p' "$f")
done

sort -o "$refs_file" "$refs_file"

today="$(date +%F)"
out="docs/project-dependencies-full.md"
: > "$out"

cat <<EOF1 >> "$out"
# Project Metadata Dependencies (Full)

Generated from metadata in \`force-app/main/default\` on ${today} by \`scripts/generate-project-docs.sh\`.

## Scope Summary

EOF1
printf -- '- Object folders: %s\n' "$(find force-app/main/default/objects -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')" >> "$out"
printf -- '- Custom objects (`__c`): %s\n' "$(find force-app/main/default/objects -mindepth 1 -maxdepth 1 -type d -name '*__c' | wc -l | tr -d ' ')" >> "$out"
printf -- '- Apex classes: %s\n' "$(find force-app/main/default/classes -name '*.cls' | wc -l | tr -d ' ')" >> "$out"
printf -- '- Triggers: %s\n' "$(find force-app/main/default/triggers -name '*.trigger' | wc -l | tr -d ' ')" >> "$out"
printf -- '- Flows: %s\n' "$(find force-app/main/default/flows -name '*.flow-meta.xml' | wc -l | tr -d ' ')" >> "$out"
printf -- '- Relationship fields (Lookup/MasterDetail): %s\n' "$(wc -l < "$refs_file" | tr -d ' ')" >> "$out"

cat <<'EOF1' >> "$out"

## Relationship Type Distribution

| Type | Count |
|---|---:|
EOF1
awk -F'\t' '{c[$3]++} END {for (k in c) printf "| `%s` | %d |\n", k, c[k]}' "$refs_file" | sort >> "$out"

cat <<'EOF1' >> "$out"

## Top Target Objects by Incoming Relationships

| Target Object | Count |
|---|---:|
EOF1
awk -F'\t' '{c[$4]++} END {for (k in c) printf "%s\t%d\n", k, c[k]}' "$refs_file" | sort -k2,2nr | awk -F'\t' '{printf "| `%s` | %s |\n", $1, $2}' >> "$out"

cat <<'EOF1' >> "$out"

## Top Source Objects by Outgoing Relationships

| Source Object | Count |
|---|---:|
EOF1
awk -F'\t' '{c[$1]++} END {for (k in c) printf "%s\t%d\n", k, c[k]}' "$refs_file" | sort -k2,2nr | awk -F'\t' '{printf "| `%s` | %s |\n", $1, $2}' >> "$out"

cat <<'EOF1' >> "$out"

## Trigger Coverage

| Trigger | SObject | File |
|---|---|---|
EOF1
rg -n '^trigger .* on ' force-app/main/default/triggers/*.trigger \
  | sed -E 's#^([^:]+):[0-9]+:trigger ([^ ]+) on ([^ ]+) .*#\2\t\3\t\1#' \
  | sort \
  | awk -F'\t' '{printf "| `%s` | `%s` | `%s` |\n", $1, $2, $3}' >> "$out"

cat <<'EOF1' >> "$out"

## Flow Record Trigger Coverage (Distinct Flow Files per Object)

| Object | Flows Referencing Object |
|---|---:|
EOF1
rg -n '<object>[^<]+</object>' force-app/main/default/flows/*.flow-meta.xml \
  | sed -E 's#^([^:]+):[0-9]+:.*<object>([^<]+)</object>.*#\1\t\2#' \
  | sort -u \
  | awk -F'\t' '{c[$2]++} END {for (k in c) printf "%s\t%d\n", k, c[k]}' \
  | sort -k2,2nr \
  | awk -F'\t' '{printf "| `%s` | %s |\n", $1, $2}' >> "$out"

cat <<'EOF1' >> "$out"

## Full Relationship Inventory (Lookup/MasterDetail)

| Source Object | Field | Type | Target Object | RelationshipName | Required | File |
|---|---|---|---|---|---|---|
EOF1
awk -F'\t' '{printf "| `%s` | `%s` | `%s` | `%s` | `%s` | `%s` | `%s` |\n", $1, $2, $3, $4, ($5==""?"(none)":$5), $6, $7}' "$refs_file" >> "$out"

coverage_out="docs/apex-coverage-snapshot.md"
{
  cat <<'EOF1'
# Apex Coverage Snapshot (Legacy Export)

Raw export preserved from the original `README.md` tracked in Git.

```text
EOF1
  if git rev-parse --verify HEAD >/dev/null 2>&1; then
    git show HEAD:README.md
  else
    echo "No Git history available for README snapshot."
  fi
  echo '```'
} > "$coverage_out"

echo "Generated: $out"
echo "Generated: $coverage_out"
