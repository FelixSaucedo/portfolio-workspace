#!/usr/bin/env bash
set -Eeuo pipefail

trap 'printf "sync: failed at line %s\n" "$LINENO" >&2' ERR

if (( $# > 1 )); then
  printf 'Usage: %s [commit-message]\n' "$0" >&2
  exit 1
fi

commit_message="${1:-chore: sync repository updates}"
workspace_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repositories=("$workspace_dir" "$workspace_dir/felixsaucedo-api" "$workspace_dir/felixsaucedo-ui")

command -v git >/dev/null
if [[ -z "${commit_message//[[:space:]]/}" ]]; then
  printf 'sync: commit message cannot be empty\n' >&2
  exit 1
fi

for repository in "${repositories[@]}"; do
  if [[ ! -d "$repository" ]]; then
    printf 'sync: missing repository %s\n' "$repository" >&2
    exit 1
  fi
  repository_root="$(git -C "$repository" rev-parse --show-toplevel)"
  if [[ "$repository_root" != "$repository" ]]; then
    printf 'sync: %s is not an independent repository\n' "$repository" >&2
    exit 1
  fi
  git -C "$repository" symbolic-ref --quiet HEAD >/dev/null
  git -C "$repository" remote get-url origin >/dev/null
  if [[ -n "$(git -C "$repository" ls-files --unmerged)" ]]; then
    printf 'sync: unresolved conflicts in %s\n' "$repository" >&2
    exit 1
  fi
  git_directory="$(git -C "$repository" rev-parse --absolute-git-dir)"
  if [[ -d "$git_directory/rebase-merge" ||
        -d "$git_directory/rebase-apply" ||
        -f "$git_directory/MERGE_HEAD" ]]; then
    printf 'sync: unfinished merge or rebase in %s\n' "$repository" >&2
    exit 1
  fi
done

for repository in "${repositories[@]}"; do
  if [[ -n "$(git -C "$repository" status --porcelain)" ]]; then
    git -C "$repository" add --all
    git -C "$repository" commit --quiet -m "$commit_message"
  fi
  git -C "$repository" push --quiet origin HEAD
done
