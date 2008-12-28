;
; Inno setup script for AlienBBC v2.4 alpha 4 (SqueezeCenter 7.3 Version)
;
#define MyAppVersion "2.4";
#define Rev "a4";

[Setup]
AppName=AlienBBC
AppVerName=AlienBBC v{#MyAppVersion}{#Rev} (SqueezeCenter 7.3 Version)
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
VersionInfoDescription=AlienBBC SqueezeCenter BBC Radio Plugin
VersionInfoTextVersion={#MyAppVersion}{#Rev}
OutputBaseFilename=AlienBBC-v{#MyAppVersion}{#Rev}_7.3
MinVersion=0,4.0.1381
WizardImageFile=compiler:wizmodernimage-is.bmp
WizardSmallImageFile=compiler:wizmodernsmallimage-is.bmp
AppendDefaultDirName=false
DisableStartupPrompt=true
Compression=zip
OutputDir=.\
LicenseFile=Licence.txt

[Files]
; Root files
Source: Alien\custom-types.conf; DestDir: {app}\server\Plugins\Alien; Flags: overwritereadonly uninsremovereadonly; DestName: custom-types.conf
Source: Alien\custom-convert.conf.windows.7_3; DestDir: {app}\server\Plugins\Alien; Flags: overwritereadonly uninsremovereadonly; DestName: custom-convert.conf
Source: Alien\RTSP.pm.7_3; DestDir: {app}\server\Plugins\Alien; Flags: overwritereadonly uninsremovereadonly replacesameversion; DestName: RTSP.pm
Source: Alien\RTSPScanHeaders.pm.7_3; DestDir: {app}\server\Plugins\Alien; Flags: overwritereadonly uninsremovereadonly replacesameversion; DestName: RTSPScanHeaders.pm
Source: Alien\install.xml.7_3; DestDir: {app}\server\Plugins\Alien; Flags: overwritereadonly uninsremovereadonly replacesameversion; DestName: install.xml
Source: Alien\strings.txt; DestDir: {app}\server\Plugins\Alien; Flags: overwritereadonly uninsremovereadonly replacesameversion; DestName: strings.txt
Source: Alien\Settings.pm; DestDir: {app}\server\Plugins\Alien; Flags: overwritereadonly uninsremovereadonly replacesameversion; DestName: Settings.pm
Source: Alien\Plugin.pm; DestDir: {app}\server\Plugins\Alien; Flags: overwritereadonly uninsremovereadonly replacesameversion; DestName: Plugin.pm
; Sub folders
Source: Alien\Addons\*.*; DestDir: {app}\server\Plugins\Alien\Addons; Flags: overwritereadonly uninsremovereadonly replacesameversion recursesubdirs
Source: Alien\Default\*.*; DestDir: {app}\server\Plugins\Alien\Default; Flags: overwritereadonly uninsremovereadonly replacesameversion recursesubdirs
Source: Alien\HTML\*.*; DestDir: {app}\server\Plugins\Alien\HTML; Flags: overwritereadonly uninsremovereadonly replacesameversion recursesubdirs
Source: Alien\Parsers\*.*; DestDir: {app}\server\Plugins\Alien\Parsers; Flags: overwritereadonly uninsremovereadonly replacesameversion recursesubdirs
Source: Alien\Playlists\*.*; DestDir: {app}\server\Plugins\Alien\Playlists; Flags: overwritereadonly uninsremovereadonly replacesameversion recursesubdirs
; MPlayer
Source: MPlayer\*.*; DestDir: {app}\server\Bin\MSWin32-x86-multi-thread; Flags: overwritereadonly promptifolder uninsremovereadonly comparetimestamp ignoreversion

[InstallDelete]
Name: {app}\server\Plugins\Alien; Type: filesandordirs
Name: {app}\server\slimserver-convert.conf; Type: files
Name: {app}\server\custom-types.conf; Type: files

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
