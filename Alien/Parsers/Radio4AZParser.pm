#
# AlienBBC Copyright (C) Jules Taplin, Craig Eales, Triode, Neil Sleightholm, Bryan Alton 2004-2008
#
# $Id$
#
# This plugin is free software; you can redistribute it and/or modify it 
# under the terms of the GNU General Public License, version 2.
#
# Parser for Radio4 A-Z ListenAgain page: http://www.bbc.co.uk/radio4/progs/radioplayer_holding.shtml
#
package Plugins::Alien::Parsers::Radio4AZParser;

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

	my @streams;

	my $title = '';
	my $href;

	my $p = HTML::Parser->new(api_version => 3,
		start_h => [
			sub {
				my $tag = shift;
				my $attr = shift;

				if ($tag eq 'a' && $attr->{'href'}) {

					if ($title =~ /^(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)$/) {
						$title = "Choice - $title";
					}

					if ($attr->{'href'} eq '/radio/aod/radio4.shtml?fm') {
						# skip this

					} elsif ($attr->{'target'} && $attr->{'target'} eq 'aod') {

						push @streams, {
							'name'   => $title,
							'url'    => fixupUrl($attr->{'href'}),
							'parser' => 'Plugins::Alien::Parsers::PlayableAodParser',
							'type'   => 'playlist',
						};
						
					} elsif ($attr->{'href'} =~ /\.r[pa]m$/) {

						push @streams, {
							'name'   => $title,
							'url'    => fixupUrl($attr->{'href'}),
							'type'   => 'audio',
						};
					}
				}
			},
			"tagname,attr"
		],
		text_h => [
			sub {
				my $t = shift;

				if ($t =~ /\S/) {
					$title = Slim::Utils::Unicode::utf8decode_guess(Slim::Formats::XML::unescapeAndTrim($t));
				}
			},
			"text"
		],
	);

	$p->parse(${$http->contentRef});

	$log->info(sprintf "found %d streams", scalar @streams);

	# return xmlbrowser hash
	return {
		'type'  => 'opml',
		'title' => $params->{'feedTitle'},
		'items' => \@streams,
	};
}

1;
