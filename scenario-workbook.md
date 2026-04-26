# Exam Scenario Workbook

This file is updated scenario by scenario.
Each section contains a practical task prompt for the learner.

## Scenario 1 - Configure Network Settings

Use interface `exam0` for this task. Do not modify `eth0` (reserved for container internet access).

Configure your VM with the following network settings on `exam0`:

- Hostname: `vm1.project100.com`
- IP address: `192.168.56.110`
- Netmask: `255.255.255.0` (`/24`)
- Gateway: `192.168.56.1`
- DNS server: `192.168.56.1`

### What to submit

- Output of `hostnamectl`
- Output of `ip -4 addr`
- Output of `ip route`
- Content of `/etc/resolv.conf` (or active DNS from NetworkManager)
- Output of `ip link show exam0`

## Scenario 2 - Configure Default Repositories

Configure your server to use two default `dnf` repositories.
Create repo definitions under `/etc/yum.repos.d/` and ensure they are enabled.

Use these example repository values (replace URLs only if your lab provides different mirrors):

- Repository 1:
  - `name=Base Practice Repo`
  - `baseurl=https://download.fedoraproject.org/pub/fedora/linux/releases/40/Everything/x86_64/os/`
  - `enabled=1`
  - `gpgcheck=0`
- Repository 2:
  - `name=Updates Practice Repo`
  - `baseurl=https://download.fedoraproject.org/pub/fedora/linux/updates/40/Everything/x86_64/`
  - `enabled=1`
  - `gpgcheck=0`

### What to submit

- Output of `dnf repolist`
- Content of your repo file in `/etc/yum.repos.d/`
- A successful package query, for example `dnf info bash`

## Scenario 3 - Debug SELinux for HTTP on Port 82

The web server is configured to use non-standard port `82`, but it is intentionally broken.
Debug and fix the system so that:

- `/var/www/html/index.html` serves this exact content:
  - `The project 100 Exam is currently Ongoing`
- HTTP works on port `82`
- The web server starts automatically at boot

Initial state for troubleshooting in this scenario:

- `index.html` has an incorrect SELinux context
- Port `82` is not yet allowed for HTTP SELinux policy
- Firewalld does not allow port `82/tcp`
- A request like `curl http://localhost:82` should fail until fixed

### What to submit

- Output of `grep -R \"^Listen\" /etc/httpd/conf* /etc/httpd/conf.d`
- Output of `systemctl status httpd --no-pager`
- Output of `semanage port -l | grep http_port_t`
- Output of `ls -Z /var/www/html/index.html`
- Output of `firewall-cmd --list-ports`
- Output of `curl -I http://localhost:82`

## Scenario 4 - Create Users, Group, and Memberships

Create the following group and users:

- Group: `vnigeria`
- User `ayo`: regular login user, secondary group `vnigeria`
- User `bode`: regular login user, secondary group `vnigeria`
- User `tobi`: non-interactive shell user, not a member of `vnigeria`

Set the password for all three users to:

- `vnigeria`

### What to submit

- Output of `getent group vnigeria`
- Output of `id ayo`
- Output of `id bode`
- Output of `id tobi`
- Output of `getent passwd tobi` (to confirm non-interactive shell)

## Scenario 5 - Configure a Cron Job

Configure a cron job that runs every 1 minute and executes:

- Echo `i will pass` as user `ayo`

Recommended result target:

- Append output to a file so it is verifiable, for example `/home/ayo/cron_pass.log`

### What to submit

- Output of `crontab -u ayo -l`
- Output of `systemctl status crond --no-pager`
- Sample content from the cron output file (for example `tail /home/ayo/cron_pass.log`)

## Scenario 6 - Create a Collaborative Directory

Create directory `/home/book/materials` with these requirements:

- Group ownership is `vnigeria`
- Only owner/group can access it (no access for others)
- Group members can read/write/enter the directory
- New files inherit group `vnigeria` automatically (setgid on directory)

### What to submit

- Output of `ls -ld /home/book/materials`
- Output of `getfacl /home/book/materials` (if ACL tools are available)
- Create a test file in the directory and show `ls -l` to verify inherited group

## Scenario 7 - Configure SSH Password Authentication

Configure SSH server to enforce password authentication and disable key-based login for testing.
Then restart `sshd` and verify login prompts for password.

### What to submit

- A config diff or grep output for:
  - `PasswordAuthentication yes`
  - `PubkeyAuthentication no`
- Output of `systemctl status sshd --no-pager`
- An `ssh localhost` test attempt showing password prompt

## Scenario 8 - Configure autofs

Configure autofs to mount the remote user home below `/netdir`.

Primary target (exam-lab style):

- `/opt/exam-data/autofs/netdir/remoteuser1` -> `/netdir/remoteuser1`

Notes:

- `autofs` and `nfs-utils` are installed.
- You must still configure autofs maps and enable/start `autofs` yourself.

### What to submit

- Your autofs map files (for example under `/etc/auto.master.d/` and `/etc/`)
- Output of `systemctl status autofs --no-pager`
- Output of `ls -la /netdir/remoteuser1`
- A write test in `/netdir/remoteuser1`

## Scenario 9 - Configure Permissions on /var/tmp/boot.log

Copy `/var/log/boot.log` to `/var/tmp/boot.log` and configure permissions so that:

- Owner is `root`
- Group is `root`
- File is not executable by anyone
- User `ayo` can read and write
- User `bode` can neither read nor write
- All other users can read

Hint: standard mode bits plus ACLs are expected for this requirement set.

### What to submit

- Output of `ls -l /var/tmp/boot.log`
- Output of `getfacl /var/tmp/boot.log`
- Test commands:
  - `sudo -u ayo cat /var/tmp/boot.log` and a write test
  - `sudo -u bode cat /var/tmp/boot.log` (should fail)

## Scenario 10 - Configure a User Account

Create a user named `dan` with:

- UID: `2002`
- Password: `vnigeria`

### What to submit

- Output of `id dan`
- Output of `getent passwd dan`
- Password verification test (for example `su - dan`)

## Scenario 11 - Locate Files Owned by kunle

Find all files owned by user `kunle` and place copies in:

- `/root/kunle_results`

### What to submit

- Command used to locate files (for example `find ... -user kunle`)
- Output of `ls -l /root/kunle_results`
- Short note on how you handled duplicate filenames (if any)

## Scenario 12 - Find String Matches in Dictionary

Find all lines in `/usr/share/dict/words` containing the string `ich` and store them in:

- `/root/ich_words`

Requirements:

- Keep original order
- No empty lines
- Lines must be exact copies from source

### What to submit

- Command used
- Output of `wc -l /root/ich_words`
- Output of `head /root/ich_words` and `tail /root/ich_words`

## Scenario 13 - Create Compressed Archives

Create these archives containing `/usr/bin` and `/usr/local`:

- `/root/archive.tar.gz` (gzip)
- `/root/archive.tar.bz2` (bzip2)
- `/root/archive.tar.xz` (xz)

### What to submit

- Commands used to create each archive
- Output of `ls -lh /root/archive.tar*`
- Verification output from:
  - `tar -tzf /root/archive.tar.gz | head`
  - `tar -tjf /root/archive.tar.bz2 | head`
  - `tar -tJf /root/archive.tar.xz | head`

## Scenario 14 - Rootless Container Auto-start Service

For user `dan`, create a rootless container named `logserver` and configure user-level systemd so it starts automatically.

Guidance:

- Pull a public, no-login image URL:
  - `quay.io/libpod/alpine:latest`
- The image’s default command exits immediately. For a **detached** container that stays up (e.g. to run a few `podman exec` commands as root), use a long-running CMD, for example:
  - `podman run -d --name logserver quay.io/libpod/alpine:latest sleep infinity`
  For an interactive shell instead, use `podman run -it --rm ... sh`.
- Do not rely on root-level container service for this task.

### What to submit

- Output of `sudo -iu dan podman ps -a`
- Output of `sudo -iu dan systemctl --user status container-logserver --no-pager`
- Output of `sudo -iu dan loginctl show-user dan | grep Linger`

## Scenario 15 - Install a Service Package and Start Its Service

Install the staged package from project path:

- `/opt/exam-data/packages/vsftpd-3.0.5-10.el10_1.1.x86_64.rpm`

Then:

- enable and start `vsftpd`
- confirm it is active and enabled at boot

### What to submit

- Command used to install the local RPM
- Output of `systemctl status vsftpd --no-pager`
- Output of `systemctl is-enabled vsftpd`
- Output timedatectl status
- Output systemctl is-enabled chronyd

## Scenario 16 - Create Script `file_search`

Create `/usr/local/bin/file_search` that finds files under `/` larger than 30k and smaller than 50k with SETUID set, and writes results to `/root/file_output`.

### What to submit

- Content of `/usr/local/bin/file_search`
- Output of `ls -l /usr/local/bin/file_search`
- Output of `wc -l /root/file_output`

## Scenario 17 - Resize Logical Volume

Resize logical volume `vo` and its filesystem to `750MiB` (acceptable range 700-830MiB).

**LVM on exam disks:** this image sets `use_devicesfile = 0` so new PVs/VGs on `/dev/sdb1` etc. show up in `vgs` and `vgchange`. If `lvcreate` fails with **device not cleared**, use **`lvcreate -Zn`** (then `mkfs` as usual), matching the seeded `vo` VG behavior.

### What to submit

- Output of `lvs`
- Output of `df -hT`
- Output showing LV/filesystem size in expected range

## Scenario 18 - Add Swap Partition

Create an additional swap partition of `512MiB`, activate it, and persist it after boot.

### What to submit

- Output of `swapon --show`
- Relevant `/etc/fstab` entry
- Output of `lsblk`

## Scenario 19 - Create Logical Volume with VFAT

Create LV `dev` in VG `tech` using `2` extents, format it as VFAT, and mount at `/mnt/dev` at boot using disk /dev/sdd

### What to submit

- Output of `vgs tech`
- Output of `lvs`
- Output of `blkid /dev/tech/dev`
- Relevant `/etc/fstab` entry and `mount | rg /mnt/dev`

## Scenario 20 - Configure System Tuning

Choose and set the recommended `tuned` profile as default.

### What to submit

- Output of `tuned-adm active`
- Output of `tuned-adm profile`
- Output of `systemctl status tuned --no-pager`

## Scenario 21 - Collaborative Directory with Sticky Bit

Set up `/shared/project` with group `devteam`, mode `2770`, sticky bit, and apply recursively.

### What to submit

- Output of `ls -ld /shared/project`
- Output of a recursive listing showing applied mode/group

## Scenario 22 - Firewalld Service and Custom Port

Allow the specific firewalld service and custom port for the installed package service:

- Service: `ftp`
- Port: `2121/tcp`

Note:

- `vsftpd` should already be running from Scenario 15.
- Keep your service running while testing firewall rules.

### What to submit

- Output of `firewall-cmd --list-all`
- Output of `firewall-cmd --list-services`
- Output of `firewall-cmd --list-ports`
- Output of `systemctl status vsftpd --no-pager`

## RHSM Registration Mode (Image Boot)

This image follows the docs-style boot-time registration approach:

- A one-shot `management-client.service` runs at boot.
- Credentials are read from `/etc/management-client/.credentials`.
- Registration is attempted once when `/etc/management-client/.run_next_boot` exists.
- After a run, the flag file is removed.

For development, keep credentials local and untracked:

- Copy `etc/management-client/.credentials.template` to `etc/management-client/.credentials`
- Fill your activation key and org ID in that local file before build/test

