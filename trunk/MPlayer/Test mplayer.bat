@echo off
:START

cls

echo.
echo Mplayer Tester
echo.
echo     1. Radio 1
echo     4. Radio 4
echo     5. Radio Five Live
echo     7. Radio 7
echo     A. The Archers
echo     W. The World Service
echo     x. Exit
echo.
echo (To stop playback and return to this menu press escape)
echo.

set /P OPT=Select Station and press enter: 
echo %OPT%

if "%OPT%"=="1" set STATION=http://www.bbc.co.uk/radio1/realaudio/media/r1live.rpm
if "%OPT%"=="4" set STATION=http://www.bbc.co.uk/radio4/realplayer/media/fmg2.rpm
if "%OPT%"=="5" set STATION=http://www.bbc.co.uk/fivelive/live/surestream.rpm
if "%OPT%"=="7" set STATION=http://www.bbc.co.uk/bbc7/realplayer/dsatg2.rpm
if "%OPT%"=="a" set STATION=http://www.bbc.co.uk/radio/aod/shows/rpms/radio4/archers.rpm
if "%OPT%"=="w" set STATION=http://www.bbc.co.uk/worldservice/ram/live_infent.ram
if "%OPT%"=="x" goto :EOF

cls

if "STATION"=="" echo Invalid station & goto :EOF

mplayer -vc null -vo null -bandwidth 10000000 -cache 128 -af volume=0,resample=44100:0:1,channels=2 -playlist %STATION%

pause

goto :START
