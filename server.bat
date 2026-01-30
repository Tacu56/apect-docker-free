@echo off
setlocal EnableDelayedExpansion

:: APECT Minecraft Server Launcher for Windows
:: CRIU Checkpointing Compatible

:: Default values
set "RAM_MIN=1G"
set "RAM_MAX=4G"
set "CPU_CORES="
set "WHITELIST=false"
set "TEMPLATE="
set "SERVER_DIR=.\server"
set "CRIU_ENABLED=false"
set "CRIU_DIR=.\checkpoints"
set "ACTION=start"

:: Parse command line arguments
:parse_args
if "%~1"=="" goto :end_parse
if /i "%~1"=="-t" (
    set "TEMPLATE=%~2"
    shift
    shift
    goto :parse_args
)
if /i "%~1"=="--template" (
    set "TEMPLATE=%~2"
    shift
    shift
    goto :parse_args
)
if /i "%~1"=="-r" (
    call :parse_ram "%~2"
    shift
    shift
    goto :parse_args
)
if /i "%~1"=="--ram" (
    call :parse_ram "%~2"
    shift
    shift
    goto :parse_args
)
if /i "%~1"=="-c" (
    set "CPU_CORES=%~2"
    shift
    shift
    goto :parse_args
)
if /i "%~1"=="--cores" (
    set "CPU_CORES=%~2"
    shift
    shift
    goto :parse_args
)
if /i "%~1"=="-w" (
    set "WHITELIST=true"
    shift
    goto :parse_args
)
if /i "%~1"=="--whitelist" (
    set "WHITELIST=true"
    shift
    goto :parse_args
)
if /i "%~1"=="-d" (
    set "SERVER_DIR=%~2"
    shift
    shift
    goto :parse_args
)
if /i "%~1"=="--dir" (
    set "SERVER_DIR=%~2"
    shift
    shift
    goto :parse_args
)
if /i "%~1"=="--criu" (
    set "CRIU_ENABLED=true"
    shift
    goto :parse_args
)
if /i "%~1"=="--criu-dir" (
    set "CRIU_DIR=%~2"
    shift
    shift
    goto :parse_args
)
if /i "%~1"=="-h" (
    goto :print_usage
)
if /i "%~1"=="--help" (
    goto :print_usage
)
echo [ERROR] Unknown option: %~1
goto :print_usage

:end_parse

:: Validate template
if "%TEMPLATE%"=="" (
    echo [ERROR] Template is required. Use -t or --template
    goto :print_usage
)

:: Get template type
call :get_template_type "%TEMPLATE%"
if "%TEMPLATE_TYPE%"=="" (
    echo [ERROR] Invalid template: %TEMPLATE%
    goto :print_usage
)

echo [INFO] Template: %TEMPLATE% ^(Type: %TEMPLATE_TYPE%^)

:: Setup server
if not exist "%SERVER_DIR%" mkdir "%SERVER_DIR%"

:: Download server jar
call :download_server_jar "%TEMPLATE_TYPE%"
if errorlevel 1 goto :error

:: Apply template
call :apply_template "%TEMPLATE%"

:: Configure whitelist
call :configure_whitelist "%WHITELIST%"

:: Accept EULA
call :accept_eula

:: Start server
call :start_server

goto :eof

:print_usage
echo.
echo APECT Minecraft Server Launcher
echo.
echo Usage: server.bat [OPTIONS]
echo.
echo Options:
echo   -t, --template ^<name^>     Server template (leaf, fabric, lifesteal, parkour, manhunt, bedwars, pixelmon, economy)
echo   -r, --ram ^<min:max^>       RAM allocation (e.g., 2G:8G or just 4G for both)
echo   -c, --cores ^<count^>       CPU cores limit (uses processor affinity)
echo   -w, --whitelist           Enable whitelist
echo   -d, --dir ^<path^>          Server directory (default: .\server)
echo   --criu                    Enable CRIU checkpointing mode
echo   -h, --help                Show this help message
echo.
echo Templates:
echo   leaf      - Leaf server (optimized Paper fork)
echo   fabric    - Fabric modded server
echo   lifesteal - Lifesteal gamemode (Leaf-based)
echo   parkour   - Parkour gamemode (Leaf-based)
echo   manhunt   - Manhunt gamemode (Leaf-based)
echo   bedwars   - Bedwars gamemode (Leaf-based)
echo   pixelmon  - Pixelmon modded (Fabric-based)
echo   economy   - Economy/survival server (Leaf-based)
echo.
echo Examples:
echo   server.bat -t leaf -r 4G:8G -c 4 -w
echo   server.bat -t pixelmon -r 8G:16G --criu
goto :eof

:parse_ram
set "ram_arg=%~1"
echo %ram_arg% | findstr ":" >nul
if errorlevel 1 (
    set "RAM_MIN=%ram_arg%"
    set "RAM_MAX=%ram_arg%"
) else (
    for /f "tokens=1,2 delims=:" %%a in ("%ram_arg%") do (
        set "RAM_MIN=%%a"
        set "RAM_MAX=%%b"
    )
)
goto :eof

:get_template_type
set "template_name=%~1"
set "TEMPLATE_TYPE="
if /i "%template_name%"=="leaf" set "TEMPLATE_TYPE=leaf"
if /i "%template_name%"=="lifesteal" set "TEMPLATE_TYPE=leaf"
if /i "%template_name%"=="parkour" set "TEMPLATE_TYPE=leaf"
if /i "%template_name%"=="manhunt" set "TEMPLATE_TYPE=leaf"
if /i "%template_name%"=="bedwars" set "TEMPLATE_TYPE=leaf"
if /i "%template_name%"=="economy" set "TEMPLATE_TYPE=leaf"
if /i "%template_name%"=="fabric" set "TEMPLATE_TYPE=fabric"
if /i "%template_name%"=="pixelmon" set "TEMPLATE_TYPE=fabric"
goto :eof

:download_server_jar
set "jar_type=%~1"
set "jar_path=%SERVER_DIR%\server.jar"

if exist "%jar_path%" (
    echo [INFO] Server jar already exists, skipping download
    goto :eof
)

echo [INFO] Downloading %jar_type% server jar...

if "%jar_type%"=="leaf" (
    set "download_url=https://api.leafmc.one/v1/download/latest"
) else if "%jar_type%"=="fabric" (
    set "download_url=https://meta.fabricmc.net/v2/versions/loader/1.20.4/0.15.6/1.0.0/server/jar"
) else (
    echo [ERROR] Unknown template type: %jar_type%
    exit /b 1
)

:: Try PowerShell download
powershell -Command "Invoke-WebRequest -Uri '%download_url%' -OutFile '%jar_path%'" 2>nul
if errorlevel 1 (
    :: Try curl as fallback
    curl -L -o "%jar_path%" "%download_url%" 2>nul
    if errorlevel 1 (
        echo [ERROR] Failed to download server jar
        exit /b 1
    )
)

echo [INFO] Server jar downloaded successfully
goto :eof

:apply_template
set "template_name=%~1"
set "template_dir=.\templates\%template_name%"

if not exist "%template_dir%" (
    echo [WARN] Template directory not found: %template_dir%
    goto :eof
)

echo [INFO] Applying template: %template_name%
xcopy /E /I /Y "%template_dir%\*" "%SERVER_DIR%\" >nul 2>&1
echo [INFO] Template applied successfully
goto :eof

:configure_whitelist
set "whitelist_val=%~1"
set "props_file=%SERVER_DIR%\server.properties"

if not exist "%props_file%" (
    echo #Minecraft server properties> "%props_file%"
    echo enable-command-block=true>> "%props_file%"
    echo gamemode=survival>> "%props_file%"
    echo difficulty=normal>> "%props_file%"
    echo spawn-protection=0>> "%props_file%"
    echo max-players=20>> "%props_file%"
    echo online-mode=true>> "%props_file%"
    echo white-list=%whitelist_val%>> "%props_file%"
    echo enforce-whitelist=%whitelist_val%>> "%props_file%"
) else (
    powershell -Command "(Get-Content '%props_file%') -replace '^white-list=.*', 'white-list=%whitelist_val%' | Set-Content '%props_file%'" 2>nul
    powershell -Command "(Get-Content '%props_file%') -replace '^enforce-whitelist=.*', 'enforce-whitelist=%whitelist_val%' | Set-Content '%props_file%'" 2>nul
)

echo [INFO] Whitelist configured: %whitelist_val%
goto :eof

:accept_eula
echo eula=true> "%SERVER_DIR%\eula.txt"
echo [INFO] EULA accepted
goto :eof

:start_server
echo [INFO] Starting Minecraft server...
echo [INFO] RAM: %RAM_MIN% - %RAM_MAX%
if not "%CPU_CORES%"=="" echo [INFO] CPU Cores: %CPU_CORES%
echo [INFO] Whitelist: %WHITELIST%
if "%CRIU_ENABLED%"=="true" echo [INFO] CRIU Mode: Enabled

:: Build JVM arguments
set "JVM_ARGS=-Xms%RAM_MIN% -Xmx%RAM_MAX%"

if "%CRIU_ENABLED%"=="true" (
    :: CRIU compatibility flags
    set "JVM_ARGS=%JVM_ARGS% -XX:+UseSerialGC"
    set "JVM_ARGS=%JVM_ARGS% -XX:-UsePerfData"
    set "JVM_ARGS=%JVM_ARGS% -XX:-UseCompressedOops"
    set "JVM_ARGS=%JVM_ARGS% -XX:-UseCompressedClassPointers"
    set "JVM_ARGS=%JVM_ARGS% -XX:-UseTLAB"
    set "JVM_ARGS=%JVM_ARGS% -XX:+AlwaysPreTouch"
) else (
    :: Standard optimized flags
    set "JVM_ARGS=%JVM_ARGS% -XX:+UseG1GC"
    set "JVM_ARGS=%JVM_ARGS% -XX:+ParallelRefProcEnabled"
    set "JVM_ARGS=%JVM_ARGS% -XX:MaxGCPauseMillis=200"
    set "JVM_ARGS=%JVM_ARGS% -XX:+UnlockExperimentalVMOptions"
    set "JVM_ARGS=%JVM_ARGS% -XX:+DisableExplicitGC"
    set "JVM_ARGS=%JVM_ARGS% -XX:+AlwaysPreTouch"
    set "JVM_ARGS=%JVM_ARGS% -XX:G1NewSizePercent=30"
    set "JVM_ARGS=%JVM_ARGS% -XX:G1MaxNewSizePercent=40"
    set "JVM_ARGS=%JVM_ARGS% -XX:G1HeapRegionSize=8M"
    set "JVM_ARGS=%JVM_ARGS% -XX:G1ReservePercent=20"
    set "JVM_ARGS=%JVM_ARGS% -XX:G1HeapWastePercent=5"
    set "JVM_ARGS=%JVM_ARGS% -XX:G1MixedGCCountTarget=4"
    set "JVM_ARGS=%JVM_ARGS% -XX:InitiatingHeapOccupancyPercent=15"
    set "JVM_ARGS=%JVM_ARGS% -XX:G1MixedGCLiveThresholdPercent=90"
    set "JVM_ARGS=%JVM_ARGS% -XX:G1RSetUpdatingPauseTimePercent=5"
    set "JVM_ARGS=%JVM_ARGS% -XX:SurvivorRatio=32"
    set "JVM_ARGS=%JVM_ARGS% -XX:+PerfDisableSharedMem"
    set "JVM_ARGS=%JVM_ARGS% -XX:MaxTenuringThreshold=1"
)

set "JVM_ARGS=%JVM_ARGS% -Dusing.aikars.flags=https://mcflags.emc.gs"
set "JVM_ARGS=%JVM_ARGS% -Daikars.new.flags=true"

pushd "%SERVER_DIR%"

:: Apply CPU affinity if specified
if not "%CPU_CORES%"=="" (
    :: Calculate affinity mask (2^cores - 1)
    set /a "affinity_mask=(1<<%CPU_CORES%)-1"
    echo [INFO] Using CPU affinity mask: !affinity_mask!
    start /affinity !affinity_mask! /wait java %JVM_ARGS% -jar server.jar nogui
) else (
    java %JVM_ARGS% -jar server.jar nogui
)

popd
goto :eof

:error
echo [ERROR] An error occurred
exit /b 1
