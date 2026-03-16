node server.js
.\venv\Scripts\activate
uvicorn main:app --reload --port 8000
flutter run -d chrome

PS D:\Refmind\refmind\backend_api> $env:Path += ";$env:LOCALAPPDATA\Android\Sdk\platform-tools"

PS D:\Refmind\refmind\backend_api> adb reverse tcp:3000 tcp:3000

(Invoke-WebRequest -Uri "https://loca.lt/mytunnelpassword" -UseBasicParsing -TimeoutSec 20).Content
$p=(Invoke-WebRequest -Uri "https://loca.lt/mytunnelpassword" -UseBasicParsing -TimeoutSec 20).Content; $p; Set-Clipboard $p