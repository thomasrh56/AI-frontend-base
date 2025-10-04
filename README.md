# GPT-2 Frontend

[![Flutter](https://img.shields.io/badge/flutter-%5E3.0-blue?logo=flutter)](https://flutter.dev)
[![Python](https://img.shields.io/badge/python-%5E3.10-blue?logo=python)](https://www.python.org)
[![FastAPI](https://img.shields.io/badge/FastAPI-%5E0.110-009688?logo=fastapi)](https://fastapi.tiangolo.com/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A minimal Flutter web frontend for a GPT-2 FastAPI backend.
The frontend communicates with the backend endpoint at `http://localhost:8000/generate`.

---

## Prerequisites

* Flutter SDK installed (with web and/or desktop support enabled) and on your `PATH`
* Python 3.10+ with virtual environment support
* Backend running (`main.py` at repository root)

---

## Running the Backend

From the repository root:

1. Create a virtual environment and install requirements:

```powershell
python -m venv venv
.\venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

2. Start the backend server:

```powershell
uvicorn main:app --reload
```

---

## Running the Frontend (Web)

From the `frontend` folder:

```powershell
flutter pub get
flutter run -d chrome
```

**Notes:**

* The backend must be reachable at `http://localhost:8000`. If using a different host/port, update the API URL in `lib/main.dart`.
* If you encounter CORS issues, enable CORS in the FastAPI backend by installing `fastapi[all]` or `fastapi` + `starlette` and adding `CORSMiddleware` in `main.py`.

---

## Windows Desktop Packaging (Optional)

You can build this Flutter app as a native Windows desktop application, so it runs without a browser.

### Requirements

* Windows 10/11
* Flutter SDK with Windows desktop support (`flutter doctor`)
* Visual Studio with *Desktop development with C++* workload
* Python 3.10+ for running the backend during development

### Quick Build

```powershell
cd frontend
flutter build windows --release
```

The release executable will be created under:

```
build\windows\runner\Release
```

---

### Launcher Script

A helper PowerShell script (`frontend/scripts/start_backend_and_app.ps1`) can:

* Start the backend (via `backend.exe` if available, or `python -m uvicorn main:app`)
* Wait until `http://127.0.0.1:8000/` is available
* Launch the built frontend executable

Usage example (from `frontend/scripts`):

```powershell
.\start_backend_and_app.ps1 -BackendScript "..\..\main.py" -AppReleaseFolder "..\build\windows\runner\Release"
```

---

### Packaging Options

* **Option A (development):** Use the launcher script with your dev Python/venv.
* **Option B (single EXE):** Use PyInstaller to create `backend.exe`.
  ⚠️ Note: PyTorch + Transformers result in very large executables and may require custom hooks.
* **Option C (portable folder):** Ship a portable Python runtime or venv alongside the backend files.
  ✅ Often the simplest approach for ML-heavy backends.

---

### Distribution

* Zip the release folder along with the backend (EXE or venv), **or**
* Use installer builders (e.g. Inno Setup) to create a proper installer.

---

## Troubleshooting

* **Torch/Transformers packaging:** Backends with PyTorch are large. Prefer portable Python + venv or host the model remotely instead of single-file EXEs.
* **CORS issues:** Desktop builds default to `http://127.0.0.1:8000`. Ensure the backend allows this origin or update the base URL in app settings.

---

## License

This project is licensed under the [MIT License](LICENSE).
