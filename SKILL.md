# SKILL: RHEL Image Mode — Exam Practice Container Builder

## Purpose
This skill enables an AI agent to build a **RHEL bootc-based container image** that functions as a fully configured exam-practice server. The container hosts **23 scenario-based questions** and ships with every package, service, file, configuration and user setup needed to attempt those scenarios — all baked into the image at build time.

The output is a **single OCI container image** runnable via `podman` or `docker` on any RHEL host. It is NOT an installer ISO; it is a server environment in a container.

---

## Skill Location
```
exam-practice/
├── SKILL.md               ← this file
├── agent.md               ← agent prompt / orchestration guide
├── containerfile          ← OCI container build file (bootc-compatible)
├── etc/
│   └── sudoers.d/
│       └── wheel          ← sudoers drop-in for exam users
├── RHEL10-image-mode.txt  ← bootc syntax & docs for RHEL 10
├── RHEL9-image-mode.txt   ← bootc syntax & docs for RHEL 9
└── sample-questions/      ← scenario question files (23 scenarios)
```

---

## When to Trigger This Skill
Use this skill when any of the following are true:
- User asks to **build, generate, or update** the RHEL exam container image
- User asks to **add, remove, or modify** exam scenarios or questions
- User asks about **bootc syntax**, image mode behaviour, or containerfile structure
- User needs to **run or test** the container locally with podman/docker
- User asks how to **validate** that all 23 scenarios work inside the container

---

## Key Concepts to Know Before Acting

### bootc (Boot-able Containers)
- bootc images are standard OCI images built on `rhel-bootc` or `rhel/rhel9-bootc` base images
- They include a full OS userspace — init system, networking, storage, systemd units
- The containerfile installs packages, drops in config files, creates users and enables services using standard `RUN`, `COPY`, and layered directives — same as any Dockerfile
- The image can later be converted (`bootc install`, `bootc switch`, or `image builder`) to disk formats: VMDK, QCOW2, RAW, ISO — but for this project the goal is **podman/docker runtime only**

### Exam Container Design Goals
- All 23 scenario questions are **pre-staged** inside the image
- All required packages are **pre-installed** (no `dnf install` during exam)
- Services needed for scenarios are **pre-enabled** via systemd
- User accounts, SSH keys, sudo rules, file permissions are set at **image build time**
- The container should start with a login prompt or drop the exam user into a configured shell

---

## Reference Files & How to Use Them

| File | When to Read It | What It Provides |
|---|---|---|
| `RHEL9-image-mode.txt` | Building for RHEL 9 base | Correct base image tag, dnf syntax, systemd unit paths, subscription config |
| `RHEL10-image-mode.txt` | Building for RHEL 10 base | RHEL 10 specific base image, package name differences, bootc version requirements |
| `sample-questions/` | Adding or validating scenarios | The 23 questions — each question maps to packages/services/files that must exist in the image |
| `containerfile` | Building the image | The actual build instructions — always edit this file to implement changes |
| `etc/sudoers.d/wheel` | User privilege config | Sudoers rule — always COPY this into the image at `/etc/sudoers.d/wheel` |

**Rule:** Always read the relevant `RHEL9-image-mode.txt` or `RHEL10-image-mode.txt` BEFORE writing or editing the containerfile. These docs are the authoritative source of correct syntax for this project.

---

## Skill Constraints & Rules
1. **Never use `apt`, `apt-get`, or `yum`** — always use `dnf` for package management
2. **Never `EXPOSE` ports unless a scenario explicitly requires it** — keep the surface minimal
3. **Always `COPY` files from the project `etc/` tree into `/etc/` in the image** — do not inline large configs into `RUN` commands
4. **Always enable services with `systemctl enable`** inside a `RUN` instruction, not at runtime
5. **The base image must match the target RHEL version** — read the txt docs to get the exact image reference
6. **Do not use `CMD /bin/bash`** as the entrypoint — the container must behave like a server; use `CMD ["/sbin/init"]` or the bootc-recommended init unless the user says otherwise
7. **All exam user accounts must be created at build time** using `RUN useradd` — never rely on runtime user creation
8. **The `wheel` sudoers file must always be included** — exam users need privilege escalation for most scenarios