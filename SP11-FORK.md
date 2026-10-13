# Surface Pro 11 forks (GeneralPawz)

Three forks, each a branch of ours on top of upstream. Our changes stay as separate commits, so pulling in upstream is a merge or rebase, and anything upstream takes over drops out.

| Repo (local path) | Our branch | Upstream | What our branch adds |
|---|---|---|---|
| [GeneralPawz/linux-sp11](https://github.com/GeneralPawz/linux-sp11) (`~/Projects/surface/linux-sp11`) | `<release>-lcd`, now `v7.2.8-arch1-sp11-lcd` | dwhinham/linux-sp11, one branch per release | kernel/DT fixes: scmi-cpufreq all-turbo OPPs, platform_profile on DT boots, surface_platform_profile `fan` param; next: DT work from the Windows data in `~/Projects/surface/sp11-windows` |
| [GeneralPawz/sp11-archlinux-repo](https://github.com/GeneralPawz/sp11-archlinux-repo) (`~/Projects/surface/sp11-archlinux-repo`) | `sp11` | dwhinham/archlinux-repo `main` | `linux-sp11/PKGBUILD` builds our kernel branch (pkgrel `.1`); `tools/sync-kernel-fork.sh`; this file |
| [GeneralPawz/omarchy](https://github.com/GeneralPawz/omarchy) (`~/Projects/surface/omarchy`) | `sp11` | omacom/omarchy `dragon` (aarch64) + `quattro` (main) | quattro merged into dragon; `aarch64-surface` platform (Ports + dwhinham pacman template, no ALARM keyring, keep mkinitcpio hooks); `sp11/sync-upstream.sh` |

## Staying in sync

```sh
# Omarchy: merge upstream dragon + quattro, run the platform tests, push
cd ~/Projects/surface/omarchy && git switch sp11 && sp11/sync-upstream.sh --push

# Kernel: rebase our commits onto dwhinham's newest release, push, update PKGBUILD
cd ~/Projects/surface/sp11-archlinux-repo && git switch sp11 && tools/sync-kernel-fork.sh --push
git commit -am "linux-sp11: <release> + our fixes" && git push

# Packaging: take dwhinham's other package updates (firmware, UCM, ...)
git fetch upstream && git merge upstream/main && git push
```

Both scripts stop on a conflict and say how to continue or undo. Omarchy conflicts are remembered (`git rerere`), so a resolution is replayed next time. A kernel release change creates a new `<release>-lcd` branch; when dwhinham bumps the release, also set `pkgver`/`pkgrel` in the PKGBUILD (keep the `.1`).

## Using the forks on the machine

- Omarchy: `omarchy dev link ~/Projects/surface/omarchy` (then reboot) runs `bin/ default/ shell/ themes/ config/` from the checkout; `omarchy dev unlink` goes back to the package. Files at fixed paths (`/etc/mkinitcpio.conf.d`, systemd units) need `omarchy dev pkg test` to build a package from the checkout.
- Kernel: `cd linux-sp11 && makepkg -s` builds the packages (long, about an hour on the device). After installing it, the `scmi-cpufreq-sp11` and `platform-profile-sp11` DKMS modules are redundant: remove them with `dkms remove`.

## Upstreaming

Each fix should also go upstream (`AGENTS.md` in Omarchy asks for that): kernel/DT patches to dwhinham and linux-arm-msm, the `aarch64-surface` platform as an Omarchy PR. When upstream takes a fix, the next sync drops our copy.
