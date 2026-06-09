# Server Onboarding Email Template

Replace all `<PLACEHOLDER>` values before sending.

---

**To:** `<EMAIL>`
**Subject:** Server Access Details & Usage Guidelines — `<SERVER_IP>`

---

Hi `<NAME>`,

Please find below the details and guidelines for accessing and using the server.

## Server Access

**Credentials:**
You will find the SSH private key file (`<KEY_NAME>`) and your password attached to this email.

**Access Command:**
Save the key file, set its permissions, and connect:

```
chmod 600 <KEY_NAME>
ssh -i <KEY_NAME> <USERNAME>@<SERVER_IP>
```

**Password:**
The password is **only for sudo access** when absolutely necessary (see sudo guidelines below). It is not needed for SSH login.

**Working Directory:**
Please place your data and code in the following directory only:

```
<WORKING_DIR>
```

**Preinstalled Tools:**
Your account is preinstalled with Conda and CUDA Toolkit `<CUDA_VERSION>`. No additional installations are necessary.

---

## Important Guidelines for Shared Server Usage

Since this is a shared server environment, please adhere to the following guidelines carefully.

### 1. Sudo Access

You have been granted sudo access to help you debug and correct errors without needing to contact the admin every time. Remember: **With Great Power, Comes Great Responsibility.**

Your password (shared in this email) is **only to be used for sudo when absolutely necessary**. Do not use it for anything else.

- **NEVER** run a command on the root directory or any system files in sudo mode.
- **NEVER** run any command outside your working directory in sudo mode.
- **BE EXTREMELY CAUTIOUS** when running any command in sudo mode — even within your working directory. Make sure you fully understand the command before executing it.
- **IF IN DOUBT, DO NOT RUN IT.** Contact the admin instead.

---

### 2. Long-Running Processes — Always Use tmux or screen

When running experiments, training jobs, or any long process, **you must use `tmux` or `screen`**. Without them, your process will be killed the moment your SSH connection drops or your terminal closes.

**tmux (recommended):**

| Action | Command |
|---|---|
| Start a new session | `tmux new -s <session_name>` |
| Detach (leave running) | `Ctrl+B`, then `D` |
| List all sessions | `tmux ls` |
| Reattach to a session | `tmux attach -t <session_name>` |
| Kill a session | `tmux kill-session -t <session_name>` |

**screen (alternative):**

| Action | Command |
|---|---|
| Start a new session | `screen -S <session_name>` |
| Detach (leave running) | `Ctrl+A`, then `D` |
| List all sessions | `screen -ls` |
| Reattach to a session | `screen -r <session_name>` |
| Kill a session | `screen -X -S <session_name> quit` |

> Please clean up your tmux/screen sessions once a job is done. Do not leave idle sessions running indefinitely.

---

### 3. GPU Coordination

You have been added to the **`<COORDINATION_GROUP>`** WhatsApp group. Please coordinate there before starting any GPU-intensive job so users do not clash.

Before starting a job, always check current GPU usage:

```
nvidia-smi
```

---

### 4. Process Etiquette

- **Do NOT kill or interfere with processes belonging to other users.** Before killing any process, verify the owner using `htop` or `ps aux | grep <process_name>`.
- If you accidentally affect another user's process, notify the admin immediately.

---

### 5. Disk Usage

- Keep all your data and code inside your designated working directory: `<WORKING_DIR>`
- Regularly clean up temporary files, intermediate checkpoints, and unused datasets.
- Check your usage with: `du -sh <WORKING_DIR>`
- Do not write large files outside your working directory.

---

If you have any questions or run into any issues, feel free to email or text me.

Best,
`<YOUR_NAME>`
