# Project 100 — Questions (learner)

Work inside the **container** (systemd / RHEL environment) unless a task says otherwise.

---

## Before you start

Open two terminal shell so you have one on the left and the other on the right. On the Left shell, run the following

### 1. Setting up the environment (on the RHEL host / VM)

1. Run the host setup script below:
  ```bash
   sudo bash <(curl -fsSL https://vnigeria.com/100-program/setup.sh)
  ```
2. After running the script, complete the prompts (full name, email, `sudo` password as needed).
3. The script installs **Podman**, **systemd** units, and pulls `**BASE_IMAGE`** if the image is not already local. Ensure the host can reach the remote image (internet access on your vm).

### 2. Making sure the environment is running

After a **successful** setup (if terminal shell didnt come up):

- The container name is typically `**project100-exam`** (persistent; **not** `podman run --rm` ).
- **Attach** to the container’s main process (recommended):
  ```bash
  sudo project100-exam-attach
  ```
- If the container is stopped, start the bootstrap unit, then attach again:
  ```bash
  sudo systemctl start project100-exam.service
  sudo project100-exam-attach
  ```
- Check status: `sudo systemctl status project100-exam.service --no-pager`

Work **inside** the container shell session you get from attach (or your instructor’s equivalent).

### 3. Submitting and finishing the scenerios

On the second one,

- **Finish early (manual):** on the **host**, run:
  ```bash
  sudo project100-exam-finish-now
  ```
  or:
  ```bash
  sudo systemctl start project100-exam-finish-now.service
  ```
  That runs automated scoring, sends results through the configured channel, and **tears down** the setup (container, host state, and related units).
- **Or wait for the timer:** about **6 hours** after setup, the same finish flow runs automatically.

After cleanup, you may need your instructor to re-run setup for another attempt.

---

## Scenario 1 - Configure Network Settings

Use interface `exam0` for this task. Do not modify `eth0` (reserved for container internet access).

Configure your Server with the following network settings on `exam0`:

- Hostname: `vm1.project100.com`
- IP address: `192.168.56.110`
- Netmask: `255.255.255.0` (`/24`)
- Gateway: `192.168.56.1`
- DNS server: `192.168.56.1`

## Scenario 2 - Configure Default Repositories

Configure your server to use two default `dnf` repositories.

Use these example repository values:

- Repository 1:
  - `NAME = Base Practice Repo`
  - `URL = https://download.fedoraproject.org/pub/fedora/linux/releases/40/Everything/x86_64/os/`
- Repository 2:
  - `NAME = Updates Practice Repo`
  - `URL = https://download.fedoraproject.org/pub/fedora/linux/updates/40/Everything/x86_64/`

## Scenario 3 - Debug SELinux for HTTP on Port 82

The web server is configured to use non-standard port `82`, but it is intentionally broken.
Debug and fix the system so that:

- `/var/www/html/index.html` serves this exact content:
  - `The project 100 is currently Ongoing`
- HTTP works on port `82`
- The web server starts automatically at boot

Initial state for troubleshooting in this scenario:

- A request like `curl http://localhost:82` should fail until fixed

## Scenario 4 - Create Users, Group, and Memberships

Create the following group and users:

- Group: `vnigeria`
- User `ayo`: regular login user, secondary group `vnigeria`
- User `bode`: regular login user, secondary group `vnigeria`
- User `tobi`: non-interactive shell user, not a member of `vnigeria`

Set the password for all three users to:

- `vnigeria`

## Scenario 5 - Configure a Cron Job

Configure a cron job that runs every 1 minute and executes:

- Echo `i will pass` as user `ayo`

Recommended result target:

- Append output to a file so it is verifiable, for example `/home/ayo/cron_pass.log`

## Scenario 6 - Create a Collaborative Directory

Create directory `/home/book/materials` with these requirements:

- Group ownership is `vnigeria`
- Only owner/group can access it (no access for others)
- Group members can read/write/enter the directory
- New files inherit group `vnigeria` automatically

## Scenario 7 - Configure SSH Password Authentication

Configure SSH to enforce password authentication and disable key-based login for testing.  
Then restart `sshd` and verify login prompts for password.

## Scenario 8 - Configure autofs

Configure autofs to mount the remote user home below `/netdir`.

Primary target (lab style):

- `/opt/exam-data/autofs/netdir/remoteuser1` -> `/netdir/remoteuser1`

## Scenario 9 - Configure Permissions on /var/tmp/boot.log

Copy `/var/log/boot.log` to `/var/tmp/boot.log` and configure permissions so that:

- Owner is `root`
- Group is `root`
- File is not executable by anyone
- User `ayo` can read and write
- User `bode` can neither read nor write
- All other users can read

## Scenario 10 - Configure a User Account

Create a user named `dan` with:

- UID: `2002`
- Password: `vnigeria`

## Scenario 11 - Locate Files Owned by kunle

Find all files owned by user `kunle` and place copies in:

- `/root/kunle_results`

## Scenario 12 - Find String Matches in Dictionary

Find all lines in `/usr/share/dict/words` containing the string `ich` and store them in:

- `/root/ich_words`

Requirements:

- Keep original order
- No empty lines
- Lines must be exact copies from source

## Scenario 13 - Create Compressed Archives

Create these archives containing `/usr/bin` and `/usr/local`:

- `/root/archive.tar.gz` (gzip)
- `/root/archive.tar.bz2` (bzip2)
- `/root/archive.tar.xz` (xz)

## Scenario 14 - Rootless Container Auto-start Service

For user `dan`, create a rootless container named `logserver` and configure user-level systemd so it starts automatically.

Guidance:

- Pull a public, no-login image URL:
  - `quay.io/libpod/alpine:latest`
- The image’s default command exits immediately. For a **detached** container that stays up (e.g. to run a few `podman exec` commands as root), use a long-running CMD, for example:
  - `podman run -d --name logserver quay.io/libpod/alpine:latest sleep infinity`
  For an interactive shell instead, use `podman run -it --rm ... sh`.
- Do not rely on root-level container service for this task.

## Scenario 15 - Install a Service Package and Start Its Service

Install the staged package from project path:

- `/opt/exam-data/packages/vsftpd-3.0.5-10.el10_1.1.x86_64.rpm`

Then:

- enable and start `vsftpd`
- confirm it is active and enabled at boot

## Scenario 16 - Create Script `file_search`

Create `/usr/local/bin/file_search` that finds files under `/` larger than 30k and smaller than 50k with SETUID set, and writes results to `/root/file_output`.

## Scenario 17 - Resize Logical Volume

Resize logical volume `vo` and its filesystem to `750MiB` (acceptable range 700-830MiB).

**LVM on exam disks:** this image sets `use_devicesfile = 0` so new PVs/VGs on `/dev/sdb1` etc. show up in `vgs` and `vgchange`. If `lvcreate` fails with **device not cleared**, use `**lvcreate -Zn`** (then `mkfs` as usual), matching the seeded `vo` VG behavior.

## Scenario 18 - Add Swap Partition

Create an additional swap partition of `512MiB`, activate it, and persist it after boot.

## Scenario 19 - Create Logical Volume with VFAT

Create LV `dev` in VG `tech` using `2` extents, format it as VFAT, and mount at `/mnt/dev` at boot using disk /dev/sdd

## Scenario 20 - Configure System Tuning

Choose and set the recommended `tuned` profile as default.

## Scenario 21 - Collaborative Directory with Sticky Bit

Set up `/shared/project` with group `devteam`, mode `2770`, sticky bit, and apply recursively.

## Scenario 22 - Firewalld Service and Custom Port

Allow the specific firewalld service and custom port for the installed package service:

- Service: `ftp`
- Port: `2121/tcp`

