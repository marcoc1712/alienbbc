#
# AlienBBC Copyright (C) Jules Taplin, Craig Eales, Triode, Neil Sleightholm, Bryan Alton 2004-2008
#
# $Id$
#
# This plugin is free software; you can redistribute it and/or modify it 
# under the terms of the GNU General Public License, version 2.
#
# A Slimserver plugin for playing streams from the BBC Radio Service using mplayer
#
# Change Log:
#   2.00    - Beta: New version of Alien BBC for use with Slimserver version 7.0.
#   2.00b2  - Fix problem with skip forward/backwards.
#           - Fix display of Gaelic accented characters
#           - Add alien icon
#           - Refresh menus on startup
#           - Updates to menu structure
#   2.00b3  - Move icon definition to install.xml file to track SC changes
#           - Move mplayer.sh to Alien/Bin (server svn15843)
#             add searching for expected mplayer locations on osx (assuming standard mplayer install)
#           - Removed NPR support except for Prarie Home Companions as that still uses RealAudio.
#           - Added a "Search A-Z" menu to search Radio A-Z for BBC radio 4,5,6 & 7.
#             For Radio 4 it uses a different parser and source page than the main
#             Radio 4 A-Z so there should be no conflict. 
#           - Updated the Deutsche Welle URLs. 
#           - Update Alien icon to have transparent background.
#   2.00b4  - Podcast update to fix title problem and add UK Only warning when necessary.
#           - Fix bug in search WebUI instance with no clients.
#           - Maintain timestamps for distribution.
#   2.00b5  - Track server change svn 16256 to make menus appear again!
#   2.00b6  - Initial support for skipping in stream from the web interface - replace repeat/shuffle with skip links
#   2.00    - Release version for SqueezeCenter 7.0
#   2.01b1  - Beta release supporting 7.1 song scanner for streams supporting this
#           - Fetch stream length from rtsp server
#           - Work around playing corrupt urls including spaces (radio5)
#   2.2b1   - Drop support for SC 7.0 - support 7.1 and 7.2
#           - Rework parsers for BBC iPlayer:
#           -  this version includes beta parsers for the iPlayer web pages (7.1+) and BBC XML feeds (SC 7.2)
#           - Remove alien skip code - only support 7.1 song scanner
#           - Fix RTSPScanHeaders to send CRLFCRLF at end of header
#   2.3b1   - Update to support 7.3 transcoding changes
#   2.4a1   - Create 7.3 extension downloader package
#           - Add mplayer downloader for windows (so we can use the extension downloader)
#   2.4a2   - Add ability to disable bandwidth parameter from settings page
#           - Add windows mplayer test from settings page
#           - Revert unix version to -cache size of 128 for streaming to players as flac
#           - Update iPlayer web parsers due to web site changes.
#           - update Local radio & regional radio handling to iPlayer web page formats
#           - removed WhatsOn Addon as BBC no longer updates the web page - iPlayer Schedules now provides similar info 
#           - Add radio 3 ident to ignore list in Settings.pm
#   2.4a3   - Improve mplayer check - add warning via all user interfaces if mplayer not found & more description text on settings page
#           - Update mplayer.sh to use paths from latest OSX MPlayer installation
#           - Allow addons to exist in any Plugin directory starting Alien (allows them to added as new plugins via Extension Downloader)
#   2.4a4   - Allow install of mplayer on path or in server Bin folder for windows


package Plugins::Alien::Plugin;

use strict;

use base qw(Slim::Plugin::OPMLBased);

use Slim::Utils::Log;
use Slim::Utils::Prefs;
use Slim::Utils::Strings qw(string);

# create log categogy before loading other modules
my $log = Slim::Utils::Log->addLogCategory({
	'category'     => 'plugin.alienbbc',
	'defaultLevel' => 'WARN',
	'description'  => getDisplayName(),
});

my $prefsServer = preferences('server');

use File::Spec::Functions qw(:ALL);

use Slim::Utils::Misc;
use Slim::Utils::Strings;
use Slim::Plugin::Favorites::Opml;

use Plugins::Alien::RTSP;
use Plugins::Alien::Settings;

my $menuUrl; # store the menu url here

my @mplayer;

# paths searched by mplayer.sh for mplayer so we can report it exists accurately
my @macMplayerPaths = (
	'/Applications/MPlayer OSX.app/Contents/Resources/External_Binaries/mplayer.app/Contents/MacOS/mplayer',
	'/Applications/MPlayer OSX.app/Contents/Resources/External_Binaries/mplayer_noaltivec.app/Contents/MacOS/mplayer',
	'/usr/local/bin/mplayer'
);


# Main plugin is a subclass of OPMLBased - not much to do here:

sub initPlugin {
	my $class = shift;

	$log->info("Initialising " . $class->_pluginDataFor('version'));

	Plugins::Alien::Settings->new($class);

	$class->SUPER::initPlugin(
		tag  => 'alien',
		menu => 'radios'
	);

	if (Slim::Utils::Misc::findbin('mplayer')) {

		$class->mplayer('found');

	} elsif ($^O =~ /^m?s?win/i) {

		require Plugins::Alien::WindowsDownloader;

		Plugins::Alien::WindowsDownloader->checkMplayer($class);

	} elsif ($^O =~/darwin/i) {

		if (grep {-x $_} @macMplayerPaths) {

			$class->mplayer('found');

		} else {

			$class->mplayer('notfound');
		}
		
	} else {

		$class->mplayer('notfound');
	}

	Plugins::Alien::Settings->importNewMenuFiles;
	Plugins::Alien::RTSP->loadMenuIcon(menuUrl());
}

sub feed {
	my $class  = shift;

	my $mplayer = $class->mplayer;

	if ($mplayer eq 'found' || $mplayer eq 'download_ok') {

		return $class->menuUrl;

	} else {

		my $mesg = {
			name        => string('PLUGIN_ALIENBBC_MPLAYER_' . ($mplayer eq 'downloading' ? 'DOWNLOADING' : 'ERROR')), 
			description => string('PLUGIN_ALIENBBC_MPLAYER_ERROR_DESC'),
		};

		# hack to get around xmlbrowser not supporting a hash in button mode
		my ($caller) = (caller(1))[3];
		return $caller =~ /setMode/ ? sub { $_[1]->($mesg) } : { title => string('PLUGIN_ALIENBBC'), items => [ $mesg ]	};
	}
}

sub menuUrl {
	my $class = shift;

	return $menuUrl if $menuUrl;

	my $dir = $prefsServer->get('playlistdir');

	if (!$dir || !-w $dir) {
		$dir = $prefsServer->get('cachedir');
	}

	my $file = catdir($dir, "alienbbc.opml");

	$menuUrl = Slim::Utils::Misc::fileURLFromPath($file);

	if (-r $file) {

		if (-w $file) {
			$log->info("alienbbc menu file: $file");

		} else {
			$log->warn("unable to write to alienbbc menu file: $file");
		}

	} else {

		$log->info("creating alienbbc menu file: $file");

		my $newopml = Slim::Plugin::Favorites::Opml->new;
		$newopml->title(Slim::Utils::Strings::string('PLUGIN_ALIENBBC'));
		$newopml->save($file);

		Plugins::Alien::Settings->importNewMenuFiles('clear');
	}

	return $menuUrl;
}

sub mplayer {
	my $class = shift;

	if (@_) {
		@_ == 2 ? $log->warn("$_[0] - $_[1]") : $log->info(@_);
		@mplayer = @_;
	}

	return wantarray ? @mplayer : $mplayer[0];
}

sub getDisplayName { 'PLUGIN_ALIENBBC' }

sub pluginDir {
	shift->_pluginDataFor('basedir');
}

sub searchDirs {
	my $class = shift;

	my @searchDirs;
	
	# find locations of main Plugin and Addons and add these to the path searched for opml menus
	my @pluginDirs = Slim::Utils::OSDetect::dirsFor('Plugins');

	for my $dir (@pluginDirs) {

		opendir(DIR, $dir);

		my @entries = readdir(DIR);

		close(DIR);

		for my $entry (@entries) {

			if ($entry =~ /^Alien/) {
				push @searchDirs, catdir($dir,$entry);
			}
		}
	}

	return @searchDirs;
}

1;
