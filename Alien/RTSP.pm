#
# AlienBBC Copyright (C) Jules Taplin, Craig Eales, Triode, Neil Sleightholm, Bryan Alton 2004-2008
#
# $Id$
#
# This plugin is free software; you can redistribute it and/or modify it 
# under the terms of the GNU General Public License, version 2.
#
package Plugins::Alien::RTSP;

use strict;

use base qw(Slim::Player::Pipeline);

use Slim::Utils::Strings qw(string);
use Slim::Utils::Misc;
use Slim::Utils::Log;
use Slim::Utils::Prefs;

use Plugins::Alien::RTSPScanHeaders;

my $log = logger('plugin.alienbbc');

Slim::Player::ProtocolHandlers->registerHandler('rtsp', __PACKAGE__);

Slim::Formats::Playlists->registerParser('rtsppl', 'Plugins::Alien::Playlists::RTSPPL');
Slim::Formats::Playlists->registerParser('smilpl', 'Plugins::Alien::Playlists::SMIL');


sub new {
	my $class = shift;
	my $args = shift;

	my $url    = $args->{'url'};
	my $client = $args->{'client'};
	my $seekdata = $client->scanData->{seekdata} ;
	my $rtspmetadata = $client->scanData->{rtspmetadata} ;

	# Check client - only stream to known slim clients
	if (!defined($client) || !$client->isPlayer()) {

		$log->warn("Alien only streams to Slim players");

		return undef;
	}

	Slim::Music::Info::setContentType($url, 'rtsp');

 	my $track    = Slim::Schema->rs('Track')->objectForUrl({
		'url'      => $url,
		'readTags' => 1
	});
	$client->pluginData( currentTrack => $track );



# RTSP URL headers are scanned but it usually completes after "new" is called except when a Seek hgas been done
# then the RTSP URL is nOT scanned and so we need to use RTSP metadata  

	if ( $rtspmetadata->{scannedurl} eq $url) {
		if ( defined ($rtspmetadata->{'endtime'})) {
		  $client->streamingProgressBar( {
				'url'     => $url,
				'bitrate' => $rtspmetadata->{'avgbitrate'} ,
				'duration'=> int($rtspmetadata->{'endtime'}/1000),
		  } );
		};
	}


	my ($command, $type, $format) = Slim::Player::TranscodingHelper::getConvertCommand($client, $url);

	unless (defined($command) && $command ne '-') {

		$log->warn("Couldn't find conversion command for $url");

		Slim::Player::Source::errorOpening($client, string('PLUGIN_ALIENBBC_NO_CONVERT_CMD'));

		return undef;
	}

	$log->info("$url, $format");

#	Slim::Music::Info::setContentType($url, $format);

	my $maxRate = 0;
	my $quality = 1;

	if (defined($client)) {
		$maxRate = Slim::Utils::Prefs::maxRate($client);
		$quality = preferences('server')->client($client)->get('lameQuality');
	}

	if (defined ($seekdata->{newtime})) {
		my $newtime = int($seekdata->{newtime});

		if ( $url =~ m"\Artsp://(.+)(\.ra\?|\.rm\?)"){
			if ($url =~m/((\?start=)|(\&start=))/ ) {
				$url =~ m/\A(.+)start=[\d:\."]+(.*)\z/;
        	      		$url = $1 . "start=$newtime" . $2;
			} 
			else {
				$url .= "&start=" . $newtime;
			}
		} 
		else {
			$url .= "?start=" . $newtime;
		}

		$client->masterOrSelf->currentsongqueue()->[-1]->{startOffset} = $newtime;
		$client->masterOrSelf->remoteStreamStartTime( Time::HiRes::time() - $newtime );
		
		# Remove seek data
		delete $client->scanData->{seekdata};
	}

	$log->debug("Modified url to play $url");

	$command = Slim::Player::TranscodingHelper::tokenizeConvertCommand($command, $type, $url, $url, 0, $maxRate, 1, $quality);

	my $self = $class->SUPER::new(undef, $command);

	${*$self}{'contentType'} = $format;

	return $self;
}

sub contentType {
	my $class = shift;

	return ${*$class}{'contentType'};
}

sub scanStream {
	my $class = shift;

	Plugins::Alien::RTSPScanHeaders->new(@_);
}

sub getMetadataFor {
	my ( $class, $client, $url, $forceCurrent ) = @_;

	my $icon = Plugins::Alien::Plugin->_pluginDataFor('icon');

	$log->debug("Begin Function for $url $icon");

	my $rtspmetadata = $client->scanData->{rtspmetadata} ;

	my $track = $client->pluginData('currentTrack');

#
# Fix to use program title extracted from iPlayer menu or Favorites to be shown rather than generic if BBC have put generic Title on program
#
	if (defined ($rtspmetadata->{'title'}) && !defined ($rtspmetadata->{'author'}) ) {
	  if ($rtspmetadata->{'title'} =~ m/BBC Radio (1|2|3|4|5 live|6 Music|7|1Xtra) \(international\)/i ) {
		$rtspmetadata->{'author'} = $rtspmetadata->{'title'};
		$rtspmetadata->{'title'} = undef;
	  }
	}

	if (defined($track)) {
		if ($track->title eq $url && defined ($rtspmetadata->{'title'} )) {
			Slim::Music::Info::setCurrentTitle( $url, $rtspmetadata->{'title'} . "  ". $rtspmetadata->{'author'}  );
			$track->title ($rtspmetadata->{'title'}) ;
			$track->update;
		}
	}

	return {
		title    =>  $rtspmetadata->{'title'}, 
		artist   =>  $rtspmetadata->{'author'} ,
		duration =>  int($rtspmetadata->{'endtime'}/1000),
		bitrate  =>  defined($track) ? $track->prettyBitRate : $rtspmetadata->{'avgbitrate'},
		icon   => $icon,
		cover  => $icon,
		type   => 'RTSP',
	};

}

# Whether or not to display buffering info while a track is loading
sub showBuffering {
	my ( $class, $client, $url ) = @_;
	
	return $client->showBuffering;
}

sub getIcon {
	my ( $class, $url ) = @_;
	$log->info( " Get Icon called url=$url");
	return 'html/images/radio.png';
}

sub canSeek {
	my ( $class, $client, $url ) = @_;
	
	$client = $client->masterOrSelf;
	
	if ( Slim::Music::Info::isPlaylist($url) ) {
		if ( my $entry = $client->remotePlaylistCurrentEntry ) {
			$url = $entry->url;
		}
	}
	
# Can only seek if bitrate and duration are known
#  *** ToDO - check if only duration is actually necessary
	my $bitrate = Slim::Music::Info::getBitrate( $url );
	my $seconds = Slim::Music::Info::getDuration( $url );

	if ($bitrate > 0  && $seconds > 0) {
	  return 1;
	}
	$log->debug("Cannot seek duration ( $seconds) or bitrate ($bitrate) may be undefined or 0");
	return 0;
}

sub canSeekError {
	my ( $class, $client, $url ) = @_;
	
	if ( Slim::Music::Info::isPlaylist($url) ) {
		if ( my $entry = $client->remotePlaylistCurrentEntry ) {
			$url = $entry->url;
		}
	}
	
	my $ct = Slim::Music::Info::contentType($url);
	
	my $mimetype;
	if (defined ($client->scanData->{rtspmetadata})) {
		my $rtspmetadata = $client->scanData->{rtspmetadata};
		$mimetype = defined( $rtspmetadata->{'mimetype'}) ? $rtspmetadata->{'mimetype'} : "unassigned";
		
	} ;

	$log->debug( "RTSP CanSeekError content type $ct mime type=". $mimetype . " url=$url " );

	if ( $mimetype eq 'audio/x-pn-multirate-realaudio-live' ) {
		return ( 'SEEK_ERROR_LIVE' );
	} 

	if ( !Slim::Music::Info::getBitrate( $url ) ) {
		return 'SEEK_ERROR_RTSP_UNKNOWN_BITRATE';
	}
	elsif ( !Slim::Music::Info::getDuration( $url ) ) {
		return 'SEEK_ERROR_RTSP_UNKNOWN_DURATION';
	}
	
	return 'SEEK_ERROR_RTSP';
}

sub getSeekData {

	my ( $class, $client, $url, $newtime ) = @_;
	
	if ( Slim::Music::Info::isPlaylist($url) ) {
		if ( my $entry = $client->remotePlaylistCurrentEntry ) {
			$url = $entry->url;
		}
	}
	
	# Determine byte offset and song length in bytes
	my $bitrate = Slim::Music::Info::getBitrate( $url ) || return;
	my $seconds = Slim::Music::Info::getDuration( $url ) || return;
		
	$bitrate /= 1000;
		
	$log->info( "Trying to seek $newtime seconds into $bitrate kbps stream of $seconds length" );
	
	my $data = {
		newoffset         => ( ( $bitrate * 1024 ) / 8 ) * $newtime,
		songLengthInBytes => ( ( $bitrate * 1024 ) / 8 ) * $seconds,
	};

	
	return $data;
}

sub setSeekData {
	my ( $class, $client, $url, $newtime, $newoffset ) = @_;
	
	my @clients;
	
	if ( Slim::Player::Sync::isSynced($client) ) {
		# if synced, save seek data for all players
		my $master = Slim::Player::Sync::masterOrSelf($client);
		push @clients, $master, @{ $master->slaves };
	}
	else {
		push @clients, $client;
	}
	
	for my $client ( @clients ) {
		# Save the new seek point
		my $currentScanData = $client->scanData ; 

		$client->scanData( {
			rtspmetadata => $currentScanData->{rtspmetadata} ,
			seekdata => {
				newtime   => $newtime,
				newoffset => $newoffset,
			},
		} );
	}
}
#
# In the future it may be necessary to distinguish between different format types using rtsp://
# but at the moment only rtsp type used.  Format returned should be the same as suffixes in custom-types.conf
# and used in custom-convert.conf.
#

sub getFormatForURL {
	my $classOrSelf = shift;
	my $url = shift;
	$log->debug("Begin Function for $url");	

	return 'rtsp';
}

# On skip, load the next track before playback
sub onJump {
	my ( $class, $client, $nextURL, $callback ) = @_;

	$log->debug("Begin Function)");	
	# If seeking, we can avoid scanning	
	if ( $client->scanData->{seekdata} ) {
		
		$callback->();
		return;
	}

	$client = $client->masterOrSelf;
	
	# Clear previous playlist entry if any
	$client->remotePlaylistCurrentEntry( undef );
	
	Slim::Utils::Scanner::Remote->scanURL( $nextURL, {
		client => $client,
		cb     => sub {
			my ( $track, $error ) = @_;
		
			if ( $track ) {
				$callback->();
			} 
			else {
				my $line1;
				$error ||= 'PROBLEM_OPENING_REMOTE_URL';

				# If the playlist was unable to load a remote URL, notify
				# This is used for logging broken stream links
				Slim::Control::Request::notifyFromArray( $client, [ 'playlist', 'cant_open', $nextURL, $error ] );

				if ( uc($error) eq $error ) {
					$line1 = $client->string($error);
				} 
				else {
					$line1 = $error;
				}

				# Show an error message
				$client->showBriefly( {
					line => [ $line1, $nextURL ],
				}, {
					scroll    => 1,
					firstline => 1,
					duration  => 5,
				} );
			}
		},
	} );

}


1;
