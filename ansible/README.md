# louielab Ansible

Unified Ansible project for the louielab fleet. Control node: **backup.louielab.cc**
(bare metal). This repo mirrors `~/ansible` on the control node; git is ground truth.

Restructured 2026-07-22 from four separate playbook silos (daily_apt_update,
deploy-monitoring, k3s-ansible, update_debian_to_trixie) into one project with a
single inventory. Old silos preserved in `_archive` (repo only, not on control node).

## Layout

    ansible.cfg              Single config. Inventory path, SSH key, pipelining,
                             fact caching, become defaults.
    inventory/hosts.yml      THE fleet inventory. One file, all groups.
    inventory/group_vars/    all.yml (ansible_user, key, loki/prometheus URLs),
                             proxmox.yml + lxc.yml (root user override).
    playbooks/               All fleet playbooks (see below).
    templates/alloy/         Six Alloy config templates, one per host class.
    files/                   Static files deployed by playbooks: docker-metrics
                             units + script, apt-maintenance.sh, wp_exporter.
    k3s/                     SELF-CONTAINED sub-project: own ansible.cfg, own
                             inventory, roles. Cluster lifecycle only (build,
                             upgrade, reset). Run from inside k3s/.

## The one deliberate duplication

The three k3s nodes appear in BOTH inventories: in `inventory/hosts.yml` as
plain Debian hosts (so apt-maintenance and monitoring cover them) and in
`k3s/inventory/hosts.yml` for cluster lifecycle. If a node changes, update both.

## Conventions

- Run everything from the project root: `cd ~/ansible && ansible-playbook playbooks/<name>.yml`
- SSH: remote user `ansible` everywhere except proxmox/lxc (root). Private key
  lives at `~/.ssh/ansible` on the control node, NOT in this repo.
- Playbooks reference templates/files with `../templates/` and `../files/`
  paths (relative to the playbook's location in playbooks/).
- group_vars lives under inventory/ (Ansible only loads it from beside the
  inventory or beside the playbook - project root does NOT work).

## Playbooks

| Playbook | Purpose | Notes |
|---|---|---|
| apt-maintenance.yml | Nightly dist-upgrade + autoremove, fleet-wide | Cron 03:30 via files/apt-maintenance.sh. Auto-reboots proxmox group only. k3s nodes get packages but NOT reboots - reboot those manually. backup also runs unattended-upgrades (deliberate overlap). |
| deploy-monitoring.yml | Install/configure Grafana Alloy per host class | Templates in templates/alloy/. docker template includes textfile collector block (required by docker-metrics). |
| deploy-docker-metrics.yml | Container-state textfile collector on docker hosts | systemd service+timer from files/. Pairs with Alloy textfile block. |
| update-monitoring-host.yml | Push an updated Alloy config to one host | Uses remote_src; config path passed as var. |
| uninstall-monitoring.yml | Remove Alloy from a host | |
| deploy-wp-exporter.yml | WordPress Prometheus exporter on the foodblog | Targets `wordpress` group. Occasional-use. |

## Power note

pve-10 is a warm standby, usually OFF overnight. When down, cron runs show exactly
these 7 unreachables: pve-10, node-1/2/3, pihole, test.leeannperugini.com,
www.designs-by-leeann.com. This is expected, not a failure.

## Sync procedure (until automated)

Changes are made on backup, tested, then mirrored here:
`tar czf ~/ansible-for-git.tgz -C ~ ansible` -> pull via SSH-browser -> extract
over X:\ansible -> commit/push from Windows.
