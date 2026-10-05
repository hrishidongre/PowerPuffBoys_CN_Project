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
This project consists of two independent backend services built with Node.js (Express) and Python (FastAPI).

- **Backend A**: Node.js with Express running on `http://localhost:3001`
- **Backend B**: Python with FastAPI and Uvicorn running on `http://localhost:3002`

---

## Directory Structure

```text
CN_project/
├── node_modules/
├── .gitignore
├── backend_A.js
├── backend_B.py
├── package.json
├── package-lock.json
├── README.md
└── requirements.txt
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