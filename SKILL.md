# SKILL: RHEL Image Mode — exam practice (builder + debugger)

## Table of contents

- [Part I — Exam practice container builder](#part-i--exam-practice-container-builder)
- [Part II — Container debugger](#part-ii--container-debugger)

---

## Part I — Exam practice container builder

### Purpose

This skill enables an AI agent to build a **RHEL bootc-based container image** that functions as a fully configured exam-practice server. The container hosts **22 scenario-based questions** and ships with every package, service, file, configuration and user setup needed to attempt those scenarios — all baked into the image at build time.

The output is a **single OCI container image** runnable via `podman` or `docker` on any RHEL host. It is NOT an installer ISO; it is a server environment in a container.

---

### Skill location

```
exam-practice/
├── SKILL.md                  ← this file (Part I + II)
├── agent.md                  ← agent prompt (builder + debugger)
├── containerfile             ← OCI container build file (bootc-compatible)
├── scenario-workbook.md      ← full scenario spec (instructors / builders)
├── Questions.md              ← learner-facing tasks only
├── setup.sh                  ← host exam environment for candidates
├── etc/
│   └── sudoers.d/
│       └── wheel             ← sudoers drop-in for exam users
├── RHEL10-image-mode.txt     ← bootc syntax & docs for RHEL 10
└── RHEL9-image-mode.txt      ← bootc syntax & docs for RHEL 9
```

---

### When to trigger Part I

Use **Part I** when any of the following are true:

- User asks to **build, generate, or update** the RHEL exam container image
- User asks to **add, remove, or modify** exam scenarios or questions
- User asks about **bootc syntax**, image mode behaviour, or containerfile structure
- User needs to **run or test** the container locally with podman/docker
- User asks how to **validate** that all **22** scenarios work inside the container

---

### Key concepts before acting

#### bootc (boot-able containers)

- bootc images are standard OCI images built on `rhel-bootc` or `rhel/rhel9-bootc` base images
- They include a full OS userspace — init system, networking, storage, systemd units
- The containerfile installs packages, drops in config files, creates users and enables services using standard `RUN`, `COPY`, and layered directives — same as any Dockerfile
- The image can later be converted (`bootc install`, `bootc switch`, or `image builder`) to disk formats: VMDK, QCOW2, RAW, ISO — but for this project the goal is **podman/docker runtime only**

#### Exam container design goals

- All **22** scenario questions are **pre-staged** inside the image
- All required packages are **pre-installed** (no `dnf install` during exam)
- Services needed for scenarios are **pre-enabled** via systemd
- User accounts, SSH keys, sudo rules, file permissions are set at **image build time**
- The container should start with a login prompt or drop the exam user into a configured shell

---

### Reference files & how to use them (Part I)

| File | When to read it | What it provides |
|------|-----------------|------------------|
| `RHEL9-image-mode.txt` | Building for RHEL 9 base | Correct base image tag, dnf syntax, systemd unit paths, subscription config |
| `RHEL10-image-mode.txt` | Building for RHEL 10 base | RHEL 10 specific base image, package name differences, bootc version requirements |
| `scenario-workbook.md` | Adding or validating scenarios | Full definitions for all scenarios — maps to packages/services/files that must exist in the image |
| `containerfile` | Building the image | The actual build instructions — always edit this file to implement changes |
| `etc/sudoers.d/wheel` | User privilege config | Sudoers rule — always COPY this into the image at `/etc/sudoers.d/wheel` |

**Rule:** Always read the relevant `RHEL9-image-mode.txt` or `RHEL10-image-mode.txt` BEFORE writing or editing the containerfile. These docs are the authoritative source of correct syntax for this project.

---

### Skill constraints & rules (Part I)

1. **Never use `apt`, `apt-get`, or `yum`** — always use `dnf` for package management
2. **Never `EXPOSE` ports unless a scenario explicitly requires it** — keep the surface minimal
3. **Always `COPY` files from the project `etc/` tree into `/etc/` in the image** — do not inline large configs into `RUN` commands
4. **Always enable services with `systemctl enable`** inside a `RUN` instruction, not at runtime
5. **The base image must match the target RHEL version** — read the txt docs to get the exact image reference
6. **Do not use `CMD /bin/bash`** as the entrypoint — the container must behave like a server; use `CMD ["/sbin/init"]` or the bootc-recommended init unless the user says otherwise
7. **All exam user accounts must be created at build time** using `RUN useradd` — never rely on runtime user creation
8. **The `wheel` sudoers file must always be included** — exam users need privilege escalation for most scenarios

---

## Part II — Container debugger

### Purpose

This skill enables an AI agent to act as a **systematic debugger** for the Project 100 exam-practice container image. It reads the containerfile, all scenario definitions in the workbook, all supporting scripts and config files, and cross-checks every moving part to find and fix issues **before** a learner runs the container.

The goal is to guarantee that a learner can do:

```bash
sudo podman run -it --rm --privileged --name exam-server <image>
```

…and have a fully functional RHEL 10 server environment where all **22** scenarios are properly staged and solvable.

---

### Skill location (debugger view)

```
exam-practice/
├── SKILL.md                   ← this file (Part II = debugger)
├── agent.md                   ← agent orchestration (builder + debugger)
├── containerfile              ← primary audit target
├── scenario-workbook.md       ← source of truth for what must exist
├── Questions.md               ← learner tasks (no submit blocks)
├── setup.sh                   ← host exam orchestration
├── RHEL10-image-mode.txt      ← authoritative bootc/RHEL10 reference
├── etc/                       ← config files COPY-ed into /etc
│   ├── httpd/conf.d/port82.conf
│   ├── firewalld/services/
│   ├── NetworkManager/conf.d/10-immutable-eth0.conf
│   ├── sudoers.d/wheel
│   ├── management-client/
│   └── systemd/system/
│       ├── exam-disk-setup.service
│       ├── exam-lvm-seed.service
│       ├── exam-secondary-iface.service
│       └── management-client.service
├── opt/exam-data/             ← data files COPY-ed into /opt/exam-data
│   ├── autofs/
│   ├── packages/
│   └── firewalld/
└── usr/local/bin/             ← helper scripts COPY-ed into /usr/local/bin
    ├── seed-exam-lvm
    ├── seed-kunle-files
    └── setup-exam-disks
exam-build.env.example         ← template for image build args (copy to gitignored exam-build.env)
```

### Host setup (`setup.sh`) — Telegram and scoring

- **Setup UX:** `setup.sh` uses colored **`[INFO]` / `[OK]` / `[WARN]` / `[ERROR]`** lines and a banner after privilege elevation. Host state dirs under **`/var/lib/project100-exam`** are created before identity, env, and SELinux labeling.
- **Registry pull:** If **`BASE_IMAGE`** is not local, **`project100-exam-ensure-container`** runs **`podman pull`** and **fails** if the pull fails (so a pushed `docker.io/...` image must be reachable before the container is created).
- **Build:** Use `exam-build.env.example` → `exam-build.env` (gitignored). Bake tokens into the image with `podman build … --build-arg-file=exam-build.env` (see comments in `containerfile`).
- **Runtime:** `project100-exam-ensure-container` extracts `/opt/exam-data/host-provision/telegram.env` from the image into **`/var/lib/project100-exam/telegram.env`**. `project100-exam-finalize` reads that file only (no repo path). Tokens are **not** installed from the repo.
- **Interactive session:** Use **`sudo project100-exam-attach`** to attach your TTY to the container’s **primary process** (`/sbin/init`), with the same binds as `project100-exam-ensure-container` (`exam-storage`, `logs`, RW `selinuxfs`). Requires **`/var/lib/project100-exam/.project100-exam-setup-complete`** (written when `setup.sh` succeeds); removed by **`project100-exam-expire`**. Do **not** use **`podman run --rm`** for the real exam: it drops the writable layer and breaks finalize/scoring.
- **Start container without TTY:** **`sudo systemctl start project100-exam.service`** (bootstrap: ensure + `podman start`). Attach is still **`project100-exam-attach`** from an interactive terminal.
- **Finish early:** **`sudo project100-exam-finish-now`** or **`sudo systemctl start project100-exam-finish-now.service`** (score, Telegram, cleanup). Set **`SETUP_SKIP_INTERACTIVE=1`** to skip the final attach at end of **`setup.sh`**.

---

### When to trigger Part II

Use **Part II** when:

- User says "debug", "audit", "check the container", "validate the containerfile"
- User says "fix the image", "something is broken", "scenario N isn't working"
- User adds a new scenario and wants a gap check
- User is about to build the image and wants a pre-flight review
- User reports a runtime error from inside a running container

---

### What Part II knows about the build environment

#### Base image

`registry.redhat.io/rhel10/rhel-bootc:10.1` — a full RHEL 10 OS image with systemd, SELinux, dnf, and bootc pre-installed. Requires a valid Red Hat subscription for the build host to resolve RHEL repos.

#### Runtime invocation

Ad-hoc developer shell (no persistent exam host dirs):

```bash
podman run -it --rm --privileged --name exam-server <image>
```

**Host-orchestrated exam** (persistent `exam-storage` / logs, scoring, Telegram): use `setup.sh` then **`project100-exam-attach`** — not `--rm`.

`--privileged` is mandatory: it gives the container the capabilities needed for systemd (PID 1), loopback device creation, LVM, firewalld, and SELinux policy tools.

---

### Container-specific constraints — always enforce

| Constraint | Detail |
|------------|--------|
| No real block devices at build time | `/dev/sdb`, `/dev/sdc` do not exist during `podman build`. Loopback images are **fully allocated** 2 GiB files (`dd`) and attached at **runtime** via a boot service. |
| SELinux context at build time | `chcon` at build time works only if the build host has SELinux enforcing AND the build runs with the right label. Prefer `semanage fcontext` + `restorecon` in a boot service OR accept that `chcon` is best-effort and note it clearly. |
| systemd inside container | `CMD ["/sbin/init"]` starts systemd as PID 1. All `systemctl enable` calls at build time only write the symlinks; services actually start at runtime when init fires. |
| No kernel modules at build time | `modprobe`, `losetup`, `mkfs.*` on real devices all require a running kernel — image files are created at build time; loops attach at runtime. |
| NetworkManager in a container | NM manages real kernel interfaces. `exam0` (Scenario 1) must be created by a runtime service (e.g. `ip link add`), not at build time. |
| Rootless podman inside a container | Scenario 14 runs rootless podman as user `dan` inside the exam container. This requires `--privileged` on the outer container AND user namespaces to be functional. |

---

### Audit checklist (run for every scenario)

For each scenario the debugger checks:

1. **Package audit** — are all packages needed to attempt AND solve the scenario installed?
2. **Service audit** — are required services enabled? Will they start cleanly with systemd?
3. **File/directory audit** — are all pre-staged files, directories, and broken fixtures in place?
4. **User/group audit** — do required users and groups exist at the right point in the build?
5. **Script audit** — do helper scripts in `usr/local/bin/` exist, are they executable, and do they do what the scenario expects?
6. **SELinux audit** — does the scenario require specific contexts? Are they set or intentionally broken?
7. **Firewall audit** — does the scenario require specific ports/services open or closed?
8. **Container constraint check** — is there anything in the scenario that a container cannot support (bare-metal-only kernel features, etc.)?
9. **Inter-scenario dependency check** — does this scenario depend on a user, file, or service created in a previous scenario? Is that dependency met or explicitly documented?
10. **Runtime vs build-time check** — are all build-time instructions correct? Do any need to be deferred to a runtime service?

---

### Known problem categories to always check

#### Category A — Package not in standard RHEL 10 repos

Some package names differ between RHEL versions or may require extra repos (CodeReady Linux Builder, EPEL, etc.). Always verify package names against RHEL10 before flagging as missing.

#### Category B — Build-time SELinux context setting

`chcon` at build time is fragile so a service may be created to change at runtime. The correct pattern for intentionally wrong contexts (exam breakage) is:

```dockerfile
chcon -t <intentionally use a wrong context here> /var/www/html/index.html
```

This only works if the build daemon has SELinux active. Document this as a known build-environment dependency.

#### Category C — Loopback disk / LVM / swap pre-staging

Scenarios 17, 18, 19 depend on pre-staged virtual disks. These are created as **fully allocated** 2 GiB image files at build time (`dd`) and attached as loopback devices at runtime by `exam-disk-setup.service`. The debugger must verify the chain:

```
dd 2 GiB files (build) → image file exists → exam-disk-setup.service attaches fixed loops
  (sdb=loop0, sdc=loop1, sdd=loop2) → exam-block-sync creates /dev/sdXn only for partitions
  on that loop → exam-lvm-seed.service creates PV/VG/LV for the seeded layout.
```

**LVM:** `etc/lvm/lvm.conf.d/99-exam-lab.conf` sets `use_devicesfile = 0` so learner VGs on exam disks appear in `vgs`/`vgchange`. **`lvcreate`** in the container often needs **`-Zn`** if wipe fails (**device not cleared**).

#### Category D — Inter-scenario user dependencies

Several scenarios reference users (`ayo`, `bode`, `dan`) that are created **by the learner** in an earlier scenario. The debugger must note which scenarios have this dependency and whether the workbook makes the ordering clear.

#### Category E — Rootless podman (Scenario 14)

Running rootless podman as a non-root user inside an already-privileged container requires:

- `newuidmap` / `newgidmap` binaries present
- `/etc/subuid` and `/etc/subgid` entries for user `dan`
- User lingering enabled (`loginctl enable-linger dan`)

The debugger checks all three.

---

### Output format standard (debugger)

When the debugger reports findings, it always uses this format:

```
SCENARIO N — <title>
  Status : ✅ PASS | ⚠️ WARNING | ❌ FAIL
  Issue  : <description of the problem>
  Root   : <where in the containerfile or project file the problem is>
  Fix    : <exact fix — containerfile line, new file content, or script change>
```

Followed by a summary table:

```
Total: 22 scenarios
  ✅ PASS    : X
  ⚠️ WARNING : Y
  ❌ FAIL    : Z
```

---

### Rules the debugger always follows

1. **Never guess — always trace the exact line** in the containerfile or script where the issue originates.
2. **Never mark a scenario PASS without checking all 10 audit items** from the checklist above.
3. **Always distinguish build-time failures from runtime failures** — they have different fixes.
4. **Always check the supporting project files** (scripts in `usr/local/bin/`, systemd units in `etc/systemd/system/`, configs in `etc/`) before marking a scenario as broken — the fix may already exist in a file.
5. **Never rewrite the entire containerfile** — produce targeted, minimal diffs for each fix.
6. **Always confirm the fix does not break other scenarios** before presenting it.
7. **Flag any scenario that requires a real physical disk or non-container kernel feature** — these need simulation via loopback or explicit documentation for the learner.
