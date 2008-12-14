#
# AlienBBC Copyright (C) Jules Taplin, Craig Eales, Triode, Neil Sleightholm, Bryan Alton 2004-2008
#
# $Id$
#
# This plugin is free software; you can redistribute it and/or modify it 
# under the terms of the GNU General Public License, version 2.
#
package Plugins::Alien::Settings;

use strict;
use base qw(Slim::Web::Settings);

use File::Next;

use Slim::Utils::Log;
use Slim::Utils::Prefs;
use Slim::Utils::Prefs::OldPrefs;
use Slim::Plugin::Favorites::Opml;

my $log   = logger('plugin.alienbbc');
my $prefs = preferences('plugin.alienbbc');

$prefs->migrate(1, sub {
	$prefs->set('ignore', Slim::Utils::Prefs::OldPrefs->get('plugin_alienbbc_ignore') || [ 'r2online_id.rm' ]);
	1;
});

$prefs->migrate(2, sub {
	$prefs->set('ignore', [ @{$prefs->get('ignore')}, 'r3g2ident.rm' ]);
	1;
});

$prefs->init({ disablebandwith => 0 });

my $plugin; # the main plugin class

sub name {
	return 'PLUGIN_ALIENBBC';
}

sub page {
	return 'plugins/Alien/settings/basic.html';
}

sub new {
	my $class = shift;
	$plugin   = shift;

	$class->SUPER::new;
}

sub handler {
	my ($class, $client, $params) = @_;

	if ($params->{'saveSettings'}) {

		# Remove empty feeds.
		my @ignore = grep { $_ ne '' } (ref $params->{'ignore'} eq 'ARRAY' ? @{$params->{'ignore'}} : $params->{'ignore'});

		$prefs->set('ignore', \@ignore);

		$prefs->set('disablebandwidth', $params->{'disablebandwidth'});
	}

	if ($params->{'reset'}) {

		$prefs->set('imported', {});
		$class->importNewMenuFiles('clear');
	}

	if ($^O =~ /Win32/ && $params->{'testmplayer'}) {

		$class->_testMplayerWindows;
	}

	my @ignore = ( @{$prefs->get('ignore')}, '' );
	my @mplayer = $plugin->mplayer;

	$params->{'ignorelist'} = \@ignore;
	$params->{'opmlfile'} = $plugin->menuUrl;
	$params->{'mplayer'} = \@mplayer;

	if (Slim::Utils::Versions->compareVersions($::VERSION, '7.3') >= 0) {
		$params->{'showbandwidth'} = 1;
		$params->{'disabledbandwidth'} = $prefs->get('disabledbandwidth');
	}

	if ($^O =~ /^m?s?win/i) {

		if ($plugin->mplayer eq 'found' || $plugin->mplayer eq 'download_ok') {

			$params->{'enabletest'} = 1;
		}

	} elsif ($plugin->mplayer ne 'found') {

		$params->{'nomplayer_os'} = ($^O =~ /darwin/i) ? 'mac' : 'unix';
	}

	return $class->SUPER::handler($client, $params);
}

sub importNewMenuFiles {
	my $class = shift;
	my $clear = shift;

	my $imported = $prefs->get('imported');

	if (!defined $imported || $clear) {
		$imported = {};
		$clear ||= 'clear';
	}

	$log->info($clear ? "clearing old menu" : "searching for new menu files to import");

	my @files = ();
	my $iter  = File::Next::files(
		{
			'file_filter' => sub { /\.opml$/ },
			'descend_filter' => sub { $_ ne 'HTML' },
		},
		$plugin->_searchDirs
	);

	while (my $file = $iter->()) {
		if ( !$imported->{ $file } || (stat($file))[9] > $imported->{ $file } ) {
			push @files, $file;
			$imported->{ $file } = time;
		}
	}

	if (@files) {
		$class->_import($clear, \@files);
		$prefs->set('imported', $imported);
	}
}

sub _import {
	my $class = shift;
	my $clear = shift;
	my $files = shift;

	my $menuOpml = Slim::Plugin::Favorites::Opml->new({ 'url' => $plugin->menuUrl });

	if ($clear) {
		splice @{$menuOpml->toplevel}, 0;
	}

	for my $file (sort @$files) {

		$log->info("importing $file");
	
		my $import = Slim::Plugin::Favorites::Opml->new({ 'url' => $file });

		if ($import->title eq 'Alien BBC') {

			for my $entry (reverse @{$import->toplevel}) {

				# remove any previously matching toplevel entry
				my $i = 0;
				
				for my $existing (@{ $menuOpml->toplevel }) {

					if ($existing->{'text'} eq $entry->{'text'}) {
						splice @{ $menuOpml->toplevel }, $i, 1;
						last;
					}

					++$i;
				}

				# add in new entry
				unshift @{ $menuOpml->toplevel }, $entry;
			}

		} else {

			my $entry;

			if (scalar @{ $import->toplevel } == 1) {

				$entry = $import->toplevel->[0];

			} else {

				$entry = {
					'text'    => $import->title,
					'outline' => $import->toplevel,
				};

			}

			# remove any previously matching toplevel entry
			my $i = 0;

			for my $existing (@{ $menuOpml->toplevel }) {

				if ($existing->{'text'} eq $entry->{'text'}) {
					splice @{ $menuOpml->toplevel }, $i, 1;
					last;
				}

				++$i;
			}

			# add in the new version
			push @{ $menuOpml->toplevel }, $entry;
		}
	}

	$menuOpml->save;
}

# create a new cmd window on windows and run mplayer with a known real stream to verify mplayer is working
sub _testMplayerWindows {

	return unless $^O =~ /^m?s?win/i;

	my $testUrl = 'http://www.bbc.co.uk/radio2/realmedia/fmg2.ram';

	Slim::bootstrap::tryModuleLoad('Win32::Process');

	my $processObj;
	
	if (!$@) {
		Win32::Process::Create(
			$processObj,
			Slim::Utils::Misc::findbin("mplayer"),
			'"' . Slim::Utils::Misc::findbin('mplayer') .  '" ' . " -cache 128 -playlist $testUrl",
			0,
			Win32::Process::NORMAL_PRIORITY_CLASS() | Win32::Process::CREATE_NEW_CONSOLE(),
			"."
		);
	}
}

1;
