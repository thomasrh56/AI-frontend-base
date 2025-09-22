# GPT-2 Frontend

This is a minimal Flutter web frontend that calls the GPT-2 FastAPI backend at `http://localhost:8000/generate`.

Prerequisites
- Flutter SDK installed and on PATH (for web support)
- Backend running (see repository root `main.py`)

Run backend (from repository root)

1. Create a virtual environment and install requirements:

```powershell
python -m venv venv; .\venv\Scripts\Activate.ps1; pip install -r requirements.txt
```

2. Run the backend:

```powershell
uvicorn main:app --reload
```

Run frontend

From `frontend` folder:

```powershell
flutter pub get
flutter run -d chrome
```

Notes
- The backend must be reachable at `http://localhost:8000`. If you run the backend on a different host/port, edit `lib/main.dart` to point to the correct URL.
- If you encounter CORS issues, you can enable CORS in the FastAPI backend by installing `fastapi[all]` or `fastapi` + `starlette` and adding CORSMiddleware in `main.py`.

## Windows desktop packaging (optional)

You can build this Flutter app as a native Windows desktop application so you don't have to run it in a browser. Below are recommended options and quick commands.

Prereqs
- Windows 10/11
- Flutter SDK with Windows desktop support enabled (run `flutter doctor`)
- Visual Studio with "Desktop development with C++" workload
- Python 3.10+ for running the backend during development

Quick build

```powershell
cd frontend
flutter build windows --release
```

The release executable will be under `build\windows\runner\Release`.

Launcher script

There's a helper PowerShell script at `frontend/scripts/start_backend_and_app.ps1` that:
- attempts to start a backend (either `backend.exe` if found or runs `python -m uvicorn main:app`),
- waits for `http://127.0.0.1:8000/` to respond, and
- launches the built frontend exe.

Usage example (from `frontend/scripts`):

```powershell
.\start_backend_and_app.ps1 -BackendScript "..\..\main.py" -AppReleaseFolder "..\build\windows\runner\Release"
```

Packaging options
- Option A (development): Use the launcher script and run the backend with your dev Python/venv.
- Option B (single exe): Use PyInstaller to create `backend.exe`. Warning: PyTorch and transformers make single-file packaging large and may need manual hooks.
- Option C (portable folder): Ship a portable Python runtime or venv next to the app and the backend Python files. This is often simpler for ML-heavy backends.

Distribution
- Zip the release folder with the backend (exe or venv) and distribute, or use installer builders (Inno Setup) to create an installer.

Troubleshooting
- Torch/transformers packaging: if your backend depends on PyTorch, packaging into a single-file exe will probably be very large and may require additional hooks for native DLLs. A recommended path is to ship the backend as a folder with a Python runtime, or host the model remotely.
- CORS: when running the app as a desktop app it will make requests to `http://127.0.0.1:8000` by default. Ensure the backend allows this origin (or configure the base URL in the app settings).

Next steps I can take for you:
- Add a small PowerShell packaging helper that copies the built app exe and a chosen backend layout into a portable folder and zips it.
- Create a PyInstaller spec file tuned for your backend (I can attempt this but packaging ML libs may require manual tweaks).
- Add an Inno Setup script template to create an installer.

Tell me which packaging option you prefer (A: development launcher, B: PyInstaller single exe, C: ship folder with Python runtime + venv) and I will implement the corresponding scripts.
