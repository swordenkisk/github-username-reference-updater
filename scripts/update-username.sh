#!/usr/bin/env bash
set -Eeuo pipefail

OLD_USERNAME="${OLD_USERNAME:-HERE}"
WORKDIR="${WORKDIR:-$HOME/github-username-update}"

fail() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

command -v gh >/dev/null 2>&1 || fail "Install GitHub CLI (gh) first."
command -v git >/dev/null 2>&1 || fail "Install Git first."
command -v perl >/dev/null 2>&1 || fail "Install Perl first."
gh auth status >/dev/null 2>&1 || fail "Run 'gh auth login' first."

read -r -p "Enter your new GitHub username: " NEW_USERNAME

if [[ ! "$NEW_USERNAME" =~ ^[A-Za-z0-9-]{1,39}$ ]]; then
  fail "That doesn't look like a valid GitHub username."
fi

ACCOUNT="$(gh api user --jq '.login' 2>/dev/null)" \
  || fail "Could not determine the authenticated GitHub account."

if [[ "$ACCOUNT" != "$NEW_USERNAME" ]]; then
  printf "GitHub CLI is authenticated as '%s'.\n" "$ACCOUNT" >&2
  printf "Authenticate as '%s' and run this script again.\n" "$NEW_USERNAME" >&2
  exit 1
fi

if [[ "$OLD_USERNAME" == "$NEW_USERNAME" ]]; then
  fail "The old and new usernames are the same."
fi

mkdir -p "$WORKDIR"
matches_file="$(mktemp)"
trap 'rm -f "$matches_file"' EXIT

repo_output="$(gh repo list "$NEW_USERNAME" \
  --limit 1000 \
  --json nameWithOwner \
  --jq '.[].nameWithOwner')" \
  || fail "Could not list repositories for '$NEW_USERNAME'."

if [[ -z "$repo_output" ]]; then
  printf "No repositories found for '%s'.\n" "$NEW_USERNAME"
  exit 0
fi

mapfile -t REPOS <<< "$repo_output"

for repo in "${REPOS[@]}"; do
  repo_name="${repo#*/}"
  dir="$WORKDIR/$repo_name"

  printf '\n=== %s ===\n' "$repo"

  if [[ -d "$dir/.git" ]]; then
    if [[ -n "$(git -C "$dir" status --porcelain)" ]]; then
      printf 'Skipping: uncommitted or untracked changes exist in %s\n' "$dir"
      continue
    fi

    if ! git -C "$dir" pull --ff-only; then
      printf 'Pull failed; skipping this repository.\n'
      continue
    fi
  elif [[ -e "$dir" ]]; then
    printf 'Skipping: %s exists but is not a Git repository.\n' "$dir"
    continue
  else
    if ! gh repo clone "$repo" "$dir"; then
      printf 'Clone failed; skipping this repository.\n'
      continue
    fi
  fi

  : > "$matches_file"
  if git -C "$dir" grep -IlFz -e "$OLD_USERNAME" -- . > "$matches_file"; then
    while IFS= read -r -d '' file; do
      OLD_USERNAME="$OLD_USERNAME" NEW_USERNAME="$NEW_USERNAME" \
        perl -pi -e 's/\Q$ENV{OLD_USERNAME}\E/$ENV{NEW_USERNAME}/g' \
          "$dir/$file"
    done < "$matches_file"
  else
    grep_status=$?
    if [[ "$grep_status" -ne 1 ]]; then
      printf 'Search failed; skipping this repository.\n'
      continue
    fi
  fi

  if git -C "$dir" diff --quiet; then
    printf 'No tracked text files contain %s.\n' "$OLD_USERNAME"
    continue
  fi

  printf 'Review the changes:\n'
  git -C "$dir" status --short
  git -C "$dir" diff --stat

  read -r -p "Type PUSH to commit and push these changes to $repo, or press Enter to skip: " answer
  if [[ "$answer" != "PUSH" ]]; then
    printf 'Skipped; changes remain in %s for review.\n' "$dir"
    continue
  fi

  if ! git -C "$dir" diff --check; then
    printf 'Whitespace check failed; changes were not committed.\n'
    continue
  fi

  if ! git -C "$dir" add -u -- .; then
    printf 'Staging failed; skipping this repository.\n'
    continue
  fi

  if ! git -C "$dir" commit -m "Update GitHub username references"; then
    printf 'Commit failed; skipping this repository.\n'
    continue
  fi

  if ! git -C "$dir" push; then
    printf 'Push failed for %s. The local commit remains in %s.\n' "$repo" "$dir"
  fi
done

printf '\nFinished processing repositories.\n'
