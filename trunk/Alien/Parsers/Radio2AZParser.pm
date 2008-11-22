#
# AlienBBC Copyright (C) Jules Taplin, Craig Eales, Triode, Neil Sleightholm, Bryan Alton 2004-2008
#
# $Id$
#
# This plugin is free software; you can redistribute it and/or modify it 
# under the terms of the GNU General Public License, version 2.
#
# Parser for Radio2 A-Z ListenAgain page: http://www.bbc.co.uk/radio2/listen/
#
package Plugins::Alien::Parsers::Radio2AZParser;

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
	my $desc  = '';
	my $day   = '';
	my $href;
	my $in_a;
	my $in_h3;
	my $in_showinfo;
	my $in_listenlinks;
	my $in_desc;

	my $p = HTML::Parser->new(api_version => 3,
		start_h => [
			sub {
				my $tag = shift;
				my $attr = shift;

				if (($tag eq 'div' || $tag eq 'p') && $attr->{'class'}) {
					$in_showinfo   = 1 if ($attr->{'class'} eq 'show-info');
					$in_listenlinks= 1 if ($attr->{'class'} eq 'listen-links');
					$in_desc       = 1 if ($attr->{'class'} eq 'description');
				}

				if ($tag eq 'a') {
					$in_a = 1;
					$href = $attr->{'href'} if $in_listenlinks;
				}

				if ($tag eq 'h3') {
					$in_h3 = 1;
				}
			},
			"tagname,attr"
		],
		text_h => [
			sub {
				my $t = shift;

				if ($in_h3 && $in_showinfo && $in_a) {
					$title = $t;
				}

				if ($in_listenlinks && $in_a) {
					$day = $t;
				}

				if ($in_desc) {
					$desc = $t;
				}
			},
			"text"
		],
		end_h => [
			sub {
				my $tag = shift;

				if ($tag eq 'p' && $in_desc) {
					$in_desc = 0;
				}

				if ($tag eq 'h3') {
					$in_h3 = 0;
				}

				if ($tag eq 'a') {
					$in_a = 0;

					if ($in_listenlinks) {

						if ($href =~ /radio2_aod.shtml/) {
							my $name = $title;

							if ($day =~/Mon|Tue|Wed|Thu|Fri|Sat|Sun/) {
								$name .= ' - ' . $day;
							}

							$href = fixupUrl($href, $url);
							$name = Slim::Utils::Unicode::utf8decode_guess(Slim::Formats::XML::unescapeAndTrim($name));
							$desc = Slim::Utils::Unicode::utf8decode_guess(Slim::Formats::XML::unescapeAndTrim($desc));

							push @streams, {
								'name'   => $name,
								'url'    => $href,
								'parser' => 'Plugins::Alien::Parsers::PlayableAodParser',
								'type'   => 'playlist',
								'description' => $desc,
							};
						}
					}
				}

				if ($tag eq 'div') {
					$in_showinfo = 0;
					$in_listenlinks = 0;
				}
			},
			"tagname"
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
