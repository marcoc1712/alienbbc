#
# AlienBBC Copyright (C) Jules Taplin, Craig Eales, Triode, Neil Sleightholm, Bryan Alton 2004-2008
#
# $Id$
#
# This plugin is free software; you can redistribute it and/or modify it 
# under the terms of the GNU General Public License, version 2.
#
# Parser to parse Aod page for a specific stream to find the url for the stream itself
#
package Plugins::Alien::Parsers::PlayableAodParser;

use strict;

use Plugins::Alien::Parsers::Utils qw(fixupUrl);

use Slim::Utils::Log;

my $log = logger('plugin.alienbbc');


sub parse
{
	my $class  = shift;
	my $http   = shift;

	my $params = $http->params('params');
	my $url    = $params->{'url'};

	my @entries;

	my $text = '';
	my $in_no_script;
	my $stream;
	my $redirect;

	my $p = HTML::Parser->new(api_version => 3,
		start_h => [
			sub {
				my $tag  = shift;
				my $attr = shift;

				if ( !$in_no_script && $tag eq 'noscript' ) {

					$in_no_script = 1;

				} elsif ( $in_no_script && $tag eq 'embed' ) {

					my $src = $attr->{'src'};

					if ( $src && $src =~ /.*\.r[pa]m/ ) {

						$stream = fixupUrl($src);
					}
				}

				if ($tag eq 'frame' && $attr->{'name'} && $attr->{'name'} eq 'bbcplayer' && $attr->{'src'} && !$stream) {

					$redirect = fixupUrl($attr->{'src'});
				}

			},
			"tagname,attr"
		],
		end_h => [
			sub {
				my $tag = shift;

				if ( $in_no_script && $tag eq "noscript" ) {
					$in_no_script = 0;
				}
			},
			"tagname"
		],
	);

	$p->parse(${$http->contentRef});

	if ($redirect) {

		$log->info("parser redirecting to $url");

		return {
			'type' => 'redirect',
			'url'  => $redirect
		};
	}

	if (!$stream) {

		$log->warn("no url found for " . $params->{'feedTitle'});

	} else {

		$log->info("found url $stream for " . $params->{'feedTitle'});
	}

	return {
		'type'  => 'opml',
		'items' => [ {
			'name' => $params->{'item'}->{'name'} || $params->{'item'}->{'title'},
			'url'  => $stream,
			'type' => 'audio',
			'description' => $params->{'item'}->{'description'},
		} ],
	};
}

1;
