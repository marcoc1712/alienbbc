package Plugins::Alien::Metadata;

# Based on Squeezecenter code - Plugin/Radiotime/Metadata.pm

use strict;

use Slim::Formats::RemoteMetadata;
use Slim::Formats::XML;
use Slim::Music::Info;
use Slim::Networking::SimpleAsyncHTTP;
use Slim::Utils::Log;
use XML::Simple;
use Date::Parse;
use POSIX qw(strftime);

my $log   = logger('formats.metadata');

use Data::Dumper;
my %stationIcons = (
	BBCROne   => 'http://radiotime-logos.s3.amazonaws.com/s24939q.png',
	BBCRTwo   => 'http://radiotime-logos.s3.amazonaws.com/s24940q.png',
	BBCRThree => 'http://radiotime-logos.s3.amazonaws.com/s24941q.png',
	BBCRFour  => 'http://radiotime-logos.s3.amazonaws.com/s24942q.png',
	BBCRFiveL => 'http://radiotime-logos.s3.amazonaws.com/s24943q.png',	
	BBCRFiveX => 'http://radiotime-logos.s3.amazonaws.com/s50459q.png',
	BBCSixMU  => 'http://radiotime-logos.s3.amazonaws.com/s44491q.png',
	BBCSeven  => 'http://radiotime-logos.s3.amazonaws.com/s6839q.png',
	BBCWrld   => 'http://radiotime-logos.s3.amazonaws.com/p38726q.png',
	OneXtra   => 'http://radiotime-logos.s3.amazonaws.com/s20277q.png',
	BBCAsian  => 'http://radiotime-logos.s3.amazonaws.com/s44490q.png',
);

my %stationIds = (
	'http://www.bbc.co.uk/radio/listen/live/r1.asx'     =>  'BBCROne',
	'http://www.bbc.co.uk/radio/listen/live/r2.asx'     =>  'BBCRTwo',
	'http://www.bbc.co.uk/radio/listen/live/r3.asx'     =>  'BBCRThree',
	'http://www.bbc.co.uk/radio/listen/live/r4.asx'     =>  'BBCRFour',
	'http://www.bbc.co.uk/radio/listen/live/r5l.asx'    =>  'BBCRFiveL',
	'http://www.bbc.co.uk/radio/listen/live/r5lsp.asx'  =>  'BBCRFiveX',
	'http://www.bbc.co.uk/radio/listen/live/r6.asx'     =>  'BBCSixMU',
	'http://www.bbc.co.uk/radio/listen/live/r7.asx'     =>  'BBCSeven',
	'http://www.bbc.co.uk/radio/listen/live/ran.asx'    =>  'BBCAsian',
	'http://www.bbc.co.uk/radio/listen/live/r1x.asx'    =>  'OneXtra',
	'http://www.bbc.co.uk/worldservice/meta/tx/nb/live_eneuk_au_nb.asx' => 'BBCWrld',
);


my $ICON = Plugins::Alien::Plugin->_pluginDataFor('icon');

sub init {
	my $class = shift;
	
	Slim::Formats::RemoteMetadata->registerParser(
		match => qr/WebAPIWMAliveid=|www\.bbc\.co\.uk\/radio\/listen\/live.+asx|www\.bbc\.co\.uk\/worldservice/,
		func  => \&parser,
	);
	
	Slim::Formats::RemoteMetadata->registerProvider(
		match => qr/WebAPIWMAliveid=|www\.bbc\.co\.uk\/radio\/listen\/live.+asx|www\.bbc\.co\.uk\/worldservice/,
		func  => \&provider,
	);
}

sub defaultMeta {
	my ( $client, $url ) = @_;
	
	return {
		title => Slim::Music::Info::getCurrentTitle($url),
		icon  => $ICON,
		type  => $client->string('RADIO'),
	};
}

sub parser {
	my ( $client, $url, $metadata ) = @_;

	# If a station is providing Icy metadata, disable metadata
	# provided by RadioTime
	if ( $metadata =~ /StreamTitle=\'([^']+)\'/ ) {
		if ( $1 ) {
			if ( $client->master->pluginData('webapimetadata' ) ) {
				$log->is_debug && $log->debug('Disabling BBC WebAPI metadata, stream has Icy metadata');
				
				Slim::Utils::Timers::killTimers( $client, \&fetchMetadata );
				$client->master->pluginData( webapimetadata => undef );
			}
			
			# Let the default metadata handler process the Icy metadata
			$client->master->pluginData( hasIcy => $url );
			return;
		}
	}
	
	# If a station is providing WMA metadata, disable metadata
	# provided by RadioTime
	elsif ( $metadata =~ /(?:CAPTION|artist|type=SONG)/ ) {
		if ( $client->master->pluginData('webapimetadata' ) ) {
			$log->is_debug && $log->debug('Disabling BBC WebAPI metadata, stream has WMA metadata');
			
			Slim::Utils::Timers::killTimers( $client, \&fetchMetadata );
			$client->master->pluginData( webapimetadata => undef );
		}
		
		# Let the default metadata handler process the WMA metadata
		$client->master->pluginData( hasIcy => $url );
		return;
	}
	
	return 1;
}

sub provider {
	my ( $client, $url ) = @_;
	my $hasIcy = $client->master->pluginData('hasIcy');
	
	if ( $hasIcy && $hasIcy ne $url ) {
		$client->master->pluginData( hasIcy => 0 );
		$hasIcy = undef;
	}
	
	return {} if $hasIcy;
	
	if ( !$client->isPlaying && !$client->isPaused ) {
		return defaultMeta( $client, $url );
	}

	if ( my $meta = $client->master->pluginData('webapimetadata') ) {
		if ( $meta->{_url} eq $url ) {
			if ( !$meta->{title} ) {
				$meta->{title} = Slim::Music::Info::getCurrentTitle($url);
			}
			
			return $meta;
		}
	}
	
	if ( !$client->master->pluginData('webapifetchingMeta') ) {
		# Fetch metadata in the background
		Slim::Utils::Timers::killTimers( $client, \&fetchMetadata );
		fetchMetadata( $client, $url );
	}
	
	return defaultMeta( $client, $url );
}

sub fetchMetadata {
	my ( $client, $url ) = @_;
	my $stationId;

	return unless $client;
	
	# Make sure client is still playing this station
	if ( Slim::Player::Playlist::url($client) ne $url ) {
		$log->is_debug && $log->debug( $client->id . " no longer playing $url, stopping metadata fetch" );
		return;
	}

	if ($url  =~ m/WebAPIWMAliveid=/) {	
		($stationId) = $url =~ m/WebAPIWMAliveid=([^&]+)/i; # support old-style stationId= and new id= URLs
	} else {
		$stationId = $stationIds{$url};
	}
	
	return unless $stationId;
	

	$log->is_debug && $log->debug( "Fetching WebAPI metadata for  url" );
	
	my $http = Slim::Networking::SimpleAsyncHTTP->new(
		\&_gotMetadata,
		\&_gotMetadataError,
		{
			client     => $client,
			url        => $url,
			timeout    => 30,
		},
	);

	my ($day, $month, $year ) = (localtime)[3..5];
# Need a date in the future  - Add one to month and then another one to change to range 1..12 and use 2nd day.
	$month  = ($month < 11) ? ($month+2): 2;
	$day = 2;
	my $enddate = sprintf('%4d-%02d-%02d',$year+1900, $month, $day);
 
	$http->get("http://www0.rdthdo.bbc.co.uk/cgi-perl/api/query.pl?method=bbc.schedule.getProgrammes&channel_id=,$stationId&start=&end=$enddate&limit=2&detail=schedule");

	$client->master->pluginData( webapifetchingMeta => 1 );
	
}

sub _gotMetadata {
	my $http      = shift;
	my $client    = $http->params('client');
	my $url       = $http->params('url');
	my $content   = $http->content;

	my $schedrec = eval { XMLin( $content , 'forcearray' => [qw(programme)], 'keyattr' => []) };

	if ( $@ ) {
		$http->error( $@ );
		_gotMetadataError( $http );
		return;
	}

	$client->master->pluginData( webapifetchingMeta => 0 );
	
	if ( $log->is_debug ) {
		$log->debug( "Raw WebAPI metadata: " . Data::Dump::dump($schedrec) );
	}
	
	my $ttl = 45;
	if ( my $cc = $http->headers->header('Cache-Control') ) {
		if ( $cc =~ m/max-age=(\d+)/i ) {
			$ttl = $1;
		}
	}

	my $meta = defaultMeta( $client, $url );

	$meta->{_url} = $url;
	
	my $programmes = $schedrec->{'schedule'}->{'programme'};

	$meta->{cover} =  $stationIcons{ $programmes->[0]->{channel_id}};
	$meta->{artist} = $programmes->[0]->{'synopsis'};
	$meta->{title} =  $programmes->[0]->{'title'};

	if (defined($programmes->[1]->{'start'} ) ) {
		$meta->{album} =  '@ ' . strftime("%H:%M", localtime(str2time($programmes->[1]->{'start'}))) . ' - '. $programmes->[1]->{'title'} ;
	} else {
		$meta->{album} =  'Next ' . $programmes->[1]->{'title'} ;
	}
	$meta->{album} .= ' - ' . $programmes->[1]->{'synopsis'};


	# Also cache the image URL in case the stream has other metadata
	if ( $meta->{cover} ) {
		my $cache = Slim::Utils::Cache->new( 'Artwork', 1, 1 );
		$cache->set( "remote_image_$url" => $meta->{cover}, 86400 );
	}
	
	if ( $log->is_debug ) {
		$log->debug( "Saved BBC metadata: " . Data::Dump::dump($meta) );
	}
	
	$client->master->pluginData( webapimetadata => $meta );
	
	$log->is_debug && $log->debug( "Will check metadata again in $ttl seconds" );
	
	Slim::Utils::Timers::setTimer(
		$client,
		time() + $ttl,
		\&fetchMetadata,
		$url,
	);

}

sub _gotMetadataError {
	my $http   = shift;
	my $client = $http->params('client');
	my $url    = $http->params('url');
	my $error  = $http->error;
	
	$log->is_debug && $log->debug( "Error fetching Web API metadata: $error" );
	
	$client->master->pluginData( webapifetchingMeta => 0 );
	
	# To avoid flooding the BBC servers in the case of errors, we just ignore further
	# metadata for this station if we get an error
	my $meta = defaultMeta( $client, $url );
	$meta->{_url} = $url;
	
	$client->master->pluginData( webapimetadata => $meta );
}


1;
