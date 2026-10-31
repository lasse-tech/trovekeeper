@echo off
setlocal enabledelayedexpansion

rem Windows counterpart to the Makefile. Same target names, same behaviour.

set "ADDON=Trovekeeper"
set "FLAVOR=_retail_"
set "TOC=%ADDON%_Mainline.toc"
set "INSTALL_DIRS=Core UI Locales Skin Media"
set "LIB_DIRS=LibStub CallbackHandler-1.0 LibDataBroker-1.1 LibDBIcon-1.0 HereBeDragons"
set "DIST_DIR=dist"
set "VENV=.build\luaenv"

for /f "tokens=2 delims=: " %%v in ('findstr /b "## Version:" "%TOC%"') do set "VERSION=%%v"

set "TARGET=%~1"
if "%TARGET%"=="" set "TARGET=help"

if /i "%TARGET%"=="help"      goto :help
if /i "%TARGET%"=="version"   goto :version
if /i "%TARGET%"=="icon"      goto :icon
if /i "%TARGET%"=="lint"      goto :lint
if /i "%TARGET%"=="check"     goto :check
if /i "%TARGET%"=="check-xml" goto :check_xml
if /i "%TARGET%"=="check-toc" goto :check_toc
if /i "%TARGET%"=="check-locales" goto :check_locales
if /i "%TARGET%"=="install"   goto :install
if /i "%TARGET%"=="debug"     goto :debug
if /i "%TARGET%"=="uninstall" goto :uninstall
if /i "%TARGET%"=="purge"     goto :purge
if /i "%TARGET%"=="dist"      goto :dist
if /i "%TARGET%"=="deploy"    goto :deploy
if /i "%TARGET%"=="release"   goto :release
if /i "%TARGET%"=="ruff"      goto :ruff
if /i "%TARGET%"=="clean"     goto :clean
if /i "%TARGET%"=="distclean" goto :distclean

echo Unknown target "%TARGET%".
goto :help

rem help: list the targets
:help
echo %ADDON% %VERSION%
for /f "tokens=1,*" %%a in ('findstr /b /r /c:"rem [abcdefghijklmnopqrstuvwxyz][abcdefghijklmnopqrstuvwxyz0123456789-]*: " "%~f0"') do echo   %%b
exit /b 0

rem version: print the addon version
:version
echo %VERSION%
exit /b 0

rem --- locating the client -------------------------------------------------

:find_addons
set "ADDONS_DIR=%WOW_RETAIL_ADDON_FOLDER%"
if not "%ADDONS_DIR%"=="" exit /b 0
call :find_wow
if "%WOW_ROOT%"=="" exit /b 1
set "ADDONS_DIR=%WOW_ROOT%\%FLAVOR%\Interface\AddOns"
exit /b 0

:find_wow
set "WOW_ROOT="
if not "%WOW_DIR%"=="" (
    set "WOW_ROOT=%WOW_DIR%"
    exit /b 0
)
for %%d in (
    "%ProgramFiles(x86)%\World of Warcraft"
    "%ProgramFiles%\World of Warcraft"
    "C:\Program Files (x86)\World of Warcraft"
    "D:\World of Warcraft"
    "C:\Games\World of Warcraft"
) do (
    if exist "%%~d\%FLAVOR%" (
        set "WOW_ROOT=%%~d"
        exit /b 0
    )
)
exit /b 1

:no_addons
echo AddOns folder not found. Set WOW_RETAIL_ADDON_FOLDER=path\to\Interface\AddOns,
echo or WOW_DIR=path\to\World of Warcraft
exit /b 1

rem --- linting -------------------------------------------------------------

:venv
if exist "%VENV%\Scripts\python.exe" exit /b 0
if not exist ".build" mkdir ".build"
python -m venv "%VENV%" || exit /b 1
"%VENV%\Scripts\pip" install --quiet lupa || exit /b 1
exit /b 0

rem icon: rebuild Media\Icon.png and brand\*.png from the SVGs
:icon
call :venv || exit /b 1
"%VENV%\Scripts\pip" install --quiet pillow || exit /b 1
where rsvg-convert >nul 2>&1 || "%VENV%\Scripts\pip" install --quiet cairosvg || exit /b 1
"%VENV%\Scripts\python" tools\build-icon.py brand Media
exit /b %errorlevel%

rem check: load every Lua file with a real Lua loader
:check
call :venv || exit /b 1
set "LUA_FILES="
for %%d in (%INSTALL_DIRS%) do (
    for /r "%%d" %%f in (*.lua) do set "LUA_FILES=!LUA_FILES! "%%f""
)
"%VENV%\Scripts\python" tools\luacheck.py !LUA_FILES!
exit /b %errorlevel%

rem check-xml: parse every XML file outside Libs\
:check_xml
set "XML_FILES="
for %%f in (*.xml) do set "XML_FILES=!XML_FILES! "%%f""
for %%d in (%INSTALL_DIRS%) do (
    for /r "%%d" %%f in (*.xml) do set "XML_FILES=!XML_FILES! "%%f""
)
python tools\xmlcheck.py !XML_FILES!
exit /b %errorlevel%

rem check-toc: TOC file list and file tree match in both directions
:check_toc
python tools\toccheck.py "%TOC%" %INSTALL_DIRS%
exit /b %errorlevel%

rem check-locales: every locale key defined and translated
:check_locales
python tools\localecheck.py Locales\enUS.lua Locales\deDE.lua -- %INSTALL_DIRS%
exit /b %errorlevel%

rem ruff: Python checks on tools\, any finding fails
:ruff
where ruff >nul 2>&1 || (echo ruff not found & exit /b 1)
ruff check --no-cache -q tools || exit /b 1
echo ruff: no findings
exit /b 0

rem lint: Lua, XML, TOC, locales, ruff (BLOCKER)
:lint
call :check         || exit /b 1
call :check_xml     || exit /b 1
call :check_toc     || exit /b 1
call :check_locales || exit /b 1
call :ruff          || exit /b 1
exit /b 0

rem --- install -------------------------------------------------------------

rem install: copy the addon into the live WoW client
:install
call :find_addons || goto :no_addons
if "%ADDONS_DIR%"=="" goto :no_addons
set "DEST=%ADDONS_DIR%\%ADDON%"
if not exist "%DEST%" mkdir "%DEST%"
copy /y "%TOC%" "%DEST%\" >nul || exit /b 1
copy /y "embeds.xml" "%DEST%\" >nul || exit /b 1
copy /y "CHANGELOG.md" "%DEST%\" >nul || exit /b 1
copy /y "LICENSE" "%DEST%\" >nul || exit /b 1
for %%d in (%INSTALL_DIRS%) do (
    if exist "%DEST%\%%d" rmdir /s /q "%DEST%\%%d"
    xcopy /e /i /q /y "%%d" "%DEST%\%%d" >nul || exit /b 1
)
if not exist "%DEST%\Libs" mkdir "%DEST%\Libs"
for %%l in (%LIB_DIRS%) do (
    if exist "%DEST%\Libs\%%l" rmdir /s /q "%DEST%\Libs\%%l"
    xcopy /e /i /q /y "Libs\%%l" "%DEST%\Libs\%%l" >nul || exit /b 1
)
echo installed %ADDON% %VERSION% -^> %DEST%
exit /b 0

rem debug: install and turn the client's Lua error display on
:debug
call :install || exit /b 1
call :find_wow
if "%WOW_ROOT%"=="" (
    echo WoW folder not found, skipped the error-display setting
    exit /b 0
)
set "CFG=%WOW_ROOT%\%FLAVOR%\WTF\Config.wtf"
if not exist "%CFG%" (
    echo no Config.wtf yet, skipped the error-display setting
    exit /b 0
)
if not exist "%CFG%.trovekeeper.bak" copy /y "%CFG%" "%CFG%.trovekeeper.bak" >nul
findstr /v /b "SET scriptErrors" "%CFG%" > "%CFG%.tmp"
echo SET scriptErrors "1">> "%CFG%.tmp"
move /y "%CFG%.tmp" "%CFG%" >nul
echo debug: scriptErrors is on in %CFG%
exit /b 0

rem uninstall: remove the addon, SavedVariables stay
:uninstall
call :find_addons || goto :no_addons
if "%ADDONS_DIR%"=="" goto :no_addons
if exist "%ADDONS_DIR%\%ADDON%" rmdir /s /q "%ADDONS_DIR%\%ADDON%"
echo removed %ADDONS_DIR%\%ADDON% (SavedVariables kept)
exit /b 0

rem purge: uninstall and delete the SavedVariables (needs CONFIRM=yes)
:purge
call :uninstall || exit /b 1
if /i not "%CONFIRM%"=="yes" (
    echo refusing to delete SavedVariables without CONFIRM=yes
    exit /b 1
)
call :find_wow
if "%WOW_ROOT%"=="" goto :no_addons
for /r "%WOW_ROOT%\%FLAVOR%\WTF" %%f in (%ADDON%.lua %ADDON%.lua.bak) do (
    if exist "%%f" del /q "%%f" && echo deleted %%f
)
echo SavedVariables deleted
exit /b 0

rem --- packaging -----------------------------------------------------------

rem dist: build dist\Trovekeeper-<version>.zip
:dist
call :lint || exit /b 1
if exist "%DIST_DIR%\%ADDON%" rmdir /s /q "%DIST_DIR%\%ADDON%"
mkdir "%DIST_DIR%\%ADDON%\Libs" 2>nul
copy /y "%TOC%" "%DIST_DIR%\%ADDON%\" >nul
copy /y "embeds.xml" "%DIST_DIR%\%ADDON%\" >nul
copy /y "CHANGELOG.md" "%DIST_DIR%\%ADDON%\" >nul
copy /y "LICENSE" "%DIST_DIR%\%ADDON%\" >nul
for %%d in (%INSTALL_DIRS%) do xcopy /e /i /q /y "%%d" "%DIST_DIR%\%ADDON%\%%d" >nul
for %%l in (%LIB_DIRS%) do xcopy /e /i /q /y "Libs\%%l" "%DIST_DIR%\%ADDON%\Libs\%%l" >nul
set "ZIP=%DIST_DIR%\%ADDON%-%VERSION%.zip"
if exist "%ZIP%" del /q "%ZIP%"
powershell -NoProfile -Command "Compress-Archive -Path '%DIST_DIR%\%ADDON%' -DestinationPath '%ZIP%'" || exit /b 1
echo built %ZIP%
exit /b 0

rem deploy: none - installation: README.md, section Installation
:deploy
echo No deploy: see README.md, section Installation
exit /b 0

rem release: print the commands that tag v<version> and push it to Forgejo
:release
echo git tag v%VERSION% ^&^& git push origin main v%VERSION%
exit /b 0

rem --- cleaning ------------------------------------------------------------

rem clean: remove build output
:clean
if exist "%DIST_DIR%" rmdir /s /q "%DIST_DIR%"
echo cleaned
exit /b 0

rem distclean: clean, plus the lint venv
:distclean
call :clean
if exist ".build" rmdir /s /q ".build"
echo distcleaned
exit /b 0
