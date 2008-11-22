package Plugins::Alien::Parsers::BBCAodXMLPlayableParser;

use strict;

use Slim::Utils::Log;

use XML::Simple;

my $log = logger('plugin.alienbbc');

sub parse {
    my $class  = shift;
    my $http   = shift;

    my $params = $http->params('params');
    my $url    = $params->{'url'};
	my $stream;

	my $xml = eval { XMLin($http->contentRef, KeyAttr => undef, ForceArray => 'media' ) };

	if ($@) {
		$log->error("$@");
		return;
	}

	for my $media (@{$xml->{'media'}}) {

		if ($media->{'encoding'} =~ /real|wmp/ && $media->{'connection'}[0] && $media->{'connection'}[0]->{'href'}) {
			$stream = $media->{'connection'}[0]->{'href'};
			last;
		}
	}

	if ($stream) {
		$log->info("$url stream $stream");
	} else {
		$log->error("no stream found for $url");
		use Data::Dumper;
		print Dumper $xml;
	}

	return {
		'type'  => 'opml',
		'items' => [ {
			'name' => $params->{'item'}->{'streamtitle'} || $params->{'feedTitle'},
			'url'  => $stream,
			'type' => 'audio',
			'description' => $params->{'item'}->{'description'},
		} ],
	};
}

1;
