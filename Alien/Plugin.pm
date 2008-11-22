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

package Plugins::Alien::Plugin;

use strict;

use base qw(Slim::Plugin::OPMLBased);

use Slim::Utils::Log;
use Slim::Utils::Prefs;

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

# Main plugin is a subclass of OPMLBased - not much to do here:

sub initPlugin {
	my $class = shift;

	$log->info("Initialising " . $class->_pluginDataFor('version'));

	Plugins::Alien::Settings->new($class);

	$class->SUPER::initPlugin(
		feed => $class->menuUrl,
		tag  => 'alien',
		menu => 'radios'
	);

	if (&Slim::Utils::OSDetect::isWindows && Slim::Utils::OSDetect::isWindows()) {

		require Plugins::Alien::WindowsDownloader;

		Plugins::Alien::WindowsDownloader->checkMplayer($class);

	} elsif (Slim::Utils::Misc::findbin('mplayer') || Slim::Utils::Misc::findbin('mplayer.exe')) {

		$class->mplayer('found');

	} else {

		$class->mplayer('notfound');
	}

	Plugins::Alien::Settings->importNewMenuFiles;
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

sub pluginDir {
	shift->_pluginDataFor('basedir');
}

sub getDisplayName { 'PLUGIN_ALIENBBC' }

1;
