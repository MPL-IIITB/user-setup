# user-setup

Script to create a shared Ubuntu user with sudo access, Miniconda, switch-cuda, SSH key pair, and optional data/code paths.

## Requirements

- Ubuntu system
- Run as root (`sudo`)
- `git` and `curl` must be installed
- `nvcc` already installed on the system

## Usage

```bash
sudo ./setup_user.sh
```

The script will prompt for:

| Prompt | Required | Notes |
|---|---|---|
| Username | Yes | |
| Password | Yes | Confirmed twice |
| Sudo access | No | y/N |
| SSH key name | Yes | e.g. `lab_key` — generates a key pair |
| Install Miniconda | No | y/N |
| Conda envs directory | If Miniconda=y | Full path, shared across users, not chowned |
| CUDA version | No | Defaults to `11.8` |
| Extra data/code paths | No | Comma-separated full paths, created if missing |

Safe to re-run — skips steps already completed (existing user, existing key, existing Miniconda install, duplicate `.bashrc` entries).

At the end, the script prints a developer checklist with exact commands to connect and finish setup (create conda env, verify CUDA, etc.).

---

## What the script sets up

1. **User** — created with `useradd`, password set, optionally added to `sudo` group
2. **SSH key pair** — ed25519 pair generated in `~/.ssh/<keyname>`, public key added to `authorized_keys`
3. **Extra paths** — created with `mkdir -p`, owned by the new user
4. **Miniconda** — installed to `~/miniconda3`, `conda init bash` run, `.condarc` written to point `envs_dirs` at your shared path
5. **switch-cuda** — repo cloned to `~/switch-cuda`, `source ~/switch-cuda/switch-cuda.sh <version>` appended to `~/.bashrc`

---

## Reverting each step

### 1. Delete the user and home directory

```bash
sudo pkill -u <username>        # kill any running processes first
sudo userdel -r <username>      # removes /home/<username> and everything in it
```

This removes: home dir, `.ssh/` keys, `~/miniconda3`, `~/switch-cuda`, `.bashrc`, `.condarc`.

### 2. Remove conda envs (if created by the user)

The conda envs directory is shared and not owned by the user, so it is **not** removed by `userdel`. Clean up manually:

```bash
sudo rm -rf /your/conda/envs/path/<env_name>   # specific env
# or
sudo rm -rf /your/conda/envs/path              # entire envs dir
```

### 3. Remove extra data/code paths

These are also not removed by `userdel`. Delete manually:

```bash
sudo rm -rf /your/extra/path
```

### 4. Undo individual steps (without deleting the user)

**Remove sudo access:**
```bash
sudo deluser <username> sudo
```

**Revoke SSH access (remove key from authorized_keys):**
```bash
sudo truncate -s 0 /home/<username>/.ssh/authorized_keys
# or delete specific key by editing the file
```

**Remove Miniconda:**
```bash
sudo rm -rf /home/<username>/miniconda3
sudo rm -f  /home/<username>/.condarc
# also remove the conda init block from ~/.bashrc (lines between
# "# >>> conda initialize >>>" and "# <<< conda initialize <<<")
```

**Remove switch-cuda:**
```bash
sudo rm -rf /home/<username>/switch-cuda
# remove the source line from ~/.bashrc:
sudo sed -i '/switch-cuda\.sh/d' /home/<username>/.bashrc
```
