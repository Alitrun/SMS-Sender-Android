
@echo off
setlocal
 
if x%ANDROID% == x set ANDROID=c:\Users\Alex\Documents\Embarcadero\Studio\18.0\PlatformSDKs\android-sdk-windows
set ANDROID_PLATFORM=%ANDROID%\platforms\android-24
set PROJ_DIR=%CD%
set VERBOSE=0
 
echo.
echo Compiling the Java service activity source files
echo.
mkdir output 2> nul
mkdir output\classes 2> nul
if x%VERBOSE% == x1 SET VERBOSE_FLAG=-verbose
javac -source 1.7 -target 1.7 %VERBOSE_FLAG% -Xlint:deprecation -cp %ANDROID_PLATFORM%\android.jar -d output\classes src\com\TestReceiver\AlarmReceiver.java
 

echo.
echo Creating jar containing the new classes
echo.
mkdir output\jar 2> nul
if x%VERBOSE% == x1 SET VERBOSE_FLAG=v
jar c%VERBOSE_FLAG%f output\jar\test_classes.jar -C output\classes com


echo.
echo Now we have the end result, in directory output\jar\
pause