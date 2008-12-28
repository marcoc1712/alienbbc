;
; Inno setup script for MPlayer 1.0rc2-4.2.1
;
#define MyAppVersion "1.0";
#define Rev "rc2";

[Setup]
AppName=MPlayer for SqueezeCenter
AppVerName=MPlayer v{#MyAppVersion}{#Rev}
AppVersion={#MyAppVersion}{#Rev}
CreateAppDir=true
UsePreviousGroup=false
AppendDefaultGroupName=false
ShowLanguageDialog=auto
DefaultDirName={code:GetInstallFolder}
InternalCompressLevel=ultra
SolidCompression=true
AllowUNCPath=false
Uninstallable=false
DirExistsWarning=no
VersionInfoVersion={#MyAppVersion}
VersionInfoDescription=MPlayer for SqueezeCenter
VersionInfoTextVersion={#MyAppVersion}{#Rev}
OutputBaseFilename=MPlayer-v{#MyAppVersion}{#Rev}
MinVersion=0,4.0.1381
WizardImageFile=compiler:wizmodernimage-is.bmp
WizardSmallImageFile=compiler:wizmodernsmallimage-is.bmp
AppendDefaultDirName=false
DisableStartupPrompt=true
Compression=zip
OutputDir=.\
LicenseFile=mplayer.txt

[Files]
; MPlayer
Source: MPlayer\*.*; DestDir: {app}\server\Bin\MSWin32-x86-multi-thread; Flags: overwritereadonly promptifolder uninsremovereadonly comparetimestamp ignoreversion

[Run]
Filename: {app}\server\Bin\MSWin32-x86-multi-thread\Test mplayer.bat; WorkingDir: {app}\server\Bin\MSWin32-x86-multi-thread; Flags: nowait postinstall; Description: Test that mplayer is working correctly.

[Code]
// Code unashamedly taken from the SqueezeCenter install
function GetInstallFolder(Param: String) : String;
var
	InstallFolder: String;
begin
	if (not RegQueryStringValue(HKLM, 'Software\Logitech\SqueezeCenter', 'Path', InstallFolder)) then
		InstallFolder := AddBackslash(ExpandConstant('{pf}')) + 'SqueezeCenter';

	Result := InstallFolder;
end;
