# Computer Network Project
---
## Group Name : **PowerpuffBoys**
## Section : A

| Team Member | Enrollment ID |
| :--- | :--- |
| Hrishi Dongre | 2401010191 |
| Pampana Sree Adithya | 2401010315 |
| Vedant Madne | 2401010499 |
| Vetriselvan R | 2401010501 |
---
A private network service platform built across four macOS laptops on one LAN.
A client types a private domain name, the team's own DNS resolves it, the team's
nginx edge terminates TLS, and one of two backend services answers.

```
              dig app.powerpuffboys.test
   client  ------------------------------->  Mac 1  dnsmasq  (primary DNS)
     |                                       Mac 4  dnsmasq  (backup DNS)
     |      answer: Mac 2's IP, TTL 30
     |
     |      https://app.powerpuffboys.test
     +------------------------------------>  Mac 2  nginx, TLS terminates here
                                               |
                                 round robin    +--> Mac 3  Backend A :3001
                                                +--> Mac 4  Backend B :3002
```

| Member | Machine | Role |
| :--- | :--- | :--- |
| Pampana Sree Adithya | Mac 1 | primary DNS |
| Vetriselvan R | Mac 2 | edge reverse proxy, load balancer, TLS |
| Hrishi Dongre | Mac 3 | Backend A, standby edge |
| Vedant Madne | Mac 4 | Backend B, backup DNS |

- **Backend A**: Node.js with Express, listening on `0.0.0.0:3001`
- **Backend B**: Python with FastAPI and Uvicorn, listening on `0.0.0.0:3002`
- **Edge**: nginx on Mac 2, the only entry point clients ever talk to

Clients never connect to a backend directly. The sections below are for running a
single backend on its own machine, or all of it on one Mac for development.

## Phase 2

Phase 2 configuration, scripts, evidence checklist and report live in
[`phase2/`](phase2/README.md). Start there: pull the repo, fill in `phase2/hosts.env`,
then run one command for your machine.

---

## Directory Structure

```text
PowerPuffBoys_CN_Project/
├── backend_A.js            Backend A, Node + Express, port 3001
├── backend_B.py            Backend B, FastAPI + Uvicorn, port 3002
├── package.json
├── requirements.txt
├── scripts/
│   └── powerpuffboys.conf  Phase 1 nginx config, kept for reference
└── phase2/
    ├── README.md           start here: who runs what
    ├── hosts.env           the one file holding every machine's IP
    ├── run.sh              one command per machine
    ├── verify.sh           per role pass/fail checks
    ├── whoami.sh           prints this Mac's IP, interface and MAC
    ├── dns/                dnsmasq config, resolver setup, TTL cutover
    ├── edge/               nginx template, certificate generation, CA trust
    ├── backend/            launchers for A and B
    ├── firewall/           Extension C pf rules and rollback
    ├── troubleshoot/       layered diagnosis script and runbook
    ├── evidence/           demo checklist and packet capture helper
    └── report/             Phase 2 report skeleton
```

---

## Prerequisites

- **Node.js**: v18 or newer
- **npm**: v9 or newer (included with Node.js)
- **Python**: 3.9 or newer
- **pip**: Python package manager

---

## Setup & Installation

### 1. Backend A (Node.js / Express)

From the project root (`CN_project/`), install the required Node modules:

```bash
npm install
```

This installs `express` and updates `package-lock.json` and `node_modules/`.

---

### 2. Backend B (Python / FastAPI)

Create and activate a Python virtual environment in the project root, then install dependencies:

#### macOS / Linux

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

#### Windows (PowerShell)

```powershell
py -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

---

## Running the Services

Open two separate terminal tabs or windows in the project root folder.

### Start Backend A

```bash
node backend_A.js
```

Backend A will run on `http://localhost:3001`.

---

### Start Backend B

Activate your virtual environment first, then run:

```bash
python backend_B.py
```

Alternatively, start Backend B using Uvicorn directly:

```bash
python -m uvicorn backend_B:app --host 0.0.0.0 --port 3002
```

Backend B will run on `http://localhost:3002`.

---

## Verifying Endpoints & Headers

### 1. Test Endpoints

Use `curl -i` to inspect the response status and headers:

#### Backend A (`:3001`)
```bash
curl -i http://localhost:3001/
curl -i http://localhost:3001/api/status
```

#### Backend B (`:3002`)
```bash
curl -i http://localhost:3002/
curl -i http://localhost:3002/api/status
```

---

### 2. Test Conditional Request Caching (`304 Not Modified`)

Test conditional GET requests with the `If-None-Match` header:

#### Backend A
```bash
curl -i -H 'If-None-Match: "backend-a-v1"' http://localhost:3001/
```

#### Backend B
```bash
curl -i -H 'If-None-Match: "backend-b-v1"' http://localhost:3002/
```

Both services will return `HTTP/1.1 304 Not Modified` when the ETag matches.