#!/bin/bash
# Keep the Surface Pro 11 kernel fork (GeneralPawz/linux-sp11) on top of dwhinham's
# newest kernel branch, and point linux-sp11/PKGBUILD at the result.
#
# dwhinham publishes one branch per kernel release (v7.2.8-arch1-sp11, ...). Our
# fixes live on <that branch>-lcd. This script:
#   1. fetches upstream,
#   2. rebases our commits onto the newest upstream release branch (a new
#      <release>-lcd branch when the release changed; commits upstream already
#      contains drop out by themselves),
#   3. with --push: pushes the branch and sets _commit/url in linux-sp11/PKGBUILD.
#
# Usage: tools/sync-kernel-fork.sh [--push]      (KERNEL_DIR defaults to ~/projects/linux-sp11)
# On a rebase conflict it stops: resolve, `git rebase --continue`, then run it again.
set -euo pipefail

kernel=${KERNEL_DIR:-$HOME/projects/linux-sp11}
fork_url=https://github.com/GeneralPawz/linux-sp11
suffix=-lcd
pkgbuild="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/linux-sp11/PKGBUILD"

say() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
die() { printf '\n\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

cd "$kernel"
git diff --quiet && git diff --cached --quiet || die "$kernel has uncommitted changes"
[[ ! -d .git/rebase-merge && ! -d .git/rebase-apply ]] || die "a rebase is in progress in $kernel - finish it first"

current=$(git rev-parse --abbrev-ref HEAD)
[[ $current == *-sp11$suffix ]] || die "check out our branch first (v<version>-arch<n>-sp11$suffix), not $current"
base_branch=${current%"$suffix"}

say "Fetching dwhinham/linux-sp11"
git fetch --quiet upstream
newest=$(git for-each-ref --format='%(refname:lstrip=3)' 'refs/remotes/upstream/v*-sp11' | sort -V | tail -1)
[[ -n $newest ]] || die "no upstream release branches found"
old_base=$(git merge-base HEAD "upstream/$base_branch")
ours=$(git rev-list --count "$old_base..HEAD")
echo "  our branch: $current ($ours commits on $base_branch)"
echo "  newest upstream release: $newest"

if [[ $newest == "$base_branch" ]]; then
  if git merge-base --is-ancestor "upstream/$base_branch" HEAD; then
    target=$current
    say "Already on top of upstream/$base_branch"
  else
    target=$current
    say "upstream/$base_branch moved: rebasing our $ours commits"
    git rebase --onto "upstream/$base_branch" "$old_base" ||
      die "rebase conflict - resolve, git rebase --continue, run again (abort: git rebase --abort)"
  fi
else
  target=$newest$suffix
  git show-ref --verify --quiet "refs/heads/$target" && die "$target exists already - check it out and run again"
  say "New release $newest: rebasing our $ours commits onto it as $target"
  git switch --quiet -c "$target"
  git rebase --onto "upstream/$newest" "$old_base" ||
    die "rebase conflict on $target - resolve, git rebase --continue, run again (abort: git rebase --abort; git switch $current)"
fi

kept=$(git rev-list --count "upstream/${target%"$suffix"}..HEAD")
say "$target: $kept of our commits on top of upstream"
git log --oneline "upstream/${target%"$suffix"}..HEAD" | sed 's/^/  /'
((kept == ours)) || echo "  $((ours - kept)) commit(s) dropped - upstream already has them"

head=$(git rev-parse HEAD)
if [[ ${1:-} == --push ]]; then
  if [[ $target == "$current" ]]; then git push --force-with-lease origin "$target"; else git push -u origin "$target"; fi
  sed -i -E "s|^url=.*|url='$fork_url'|; s|^_commit=.*|_commit=$head|" "$pkgbuild"
  say "PKGBUILD now builds $fork_url @ ${head:0:12}"
  echo "  review: git -C $(dirname "$pkgbuild")/.. diff   (pkgver/pkgrel too when the release changed)"
else
  echo "  not pushed - run with --push to push and update PKGBUILD (_commit=$head)"
fi
