#
# AlienBBC Copyright (C) Jules Taplin, Craig Eales, Triode, Neil Sleightholm, Bryan Alton 2004-2008
#
# $Id$
#
# This plugin is free software; you can redistribute it and/or modify it 
# under the terms of the GNU General Public License, version 2.
#
# Parser for BBC7 ListenAgain pages: http://www.bbc.co.uk/bbc7/listenagain/<day of week>/
#
package Plugins::Alien::Parsers::BBC7ListenAgain;

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
	my $in_tr;
	my $in_mgrey;
	my $in_lgrey;
	my $in_strong;
	my $href;

	my $p = HTML::Parser->new(api_version => 3,
		start_h => [
			sub {
				my $tag = shift;
				my $attr = shift;

				$in_tr if ($tag eq 'tr');

				if ($tag eq 'td' && $attr->{'class'}) {
					$in_mgrey = 1 if ($attr->{'class'} eq 'mgrey');
					$in_lgrey = 1 if ($attr->{'class'} eq 'lgrey');
				}

				if ($tag eq 'a' && ($in_mgrey || $in_lgrey)) {
					$href = $attr->{'href'};
				}

				$in_strong = 1 if ($tag eq 'strong');
			},
			"tagname,attr"
		],
		text_h => [
			sub {
				my $t = shift;

				if ($in_mgrey && $in_strong) {
					$title = $t;
				}

				if ($in_lgrey && $in_strong) {
					$title .= ' ' . $t;
				}

				if ($in_lgrey && !$in_strong) {
					$desc .= $t;
				}
			},
			"text"
		],
		end_h => [
			sub {
				my $tag = shift;

				if ($tag eq 'strong') {
					$in_strong = 0;
				}

				if ($tag eq 'td') {
					$in_mgrey = $in_lgrey = 0;
				}

				if ($tag eq 'tr') {

					$href  = fixupUrl($href, $url);
					$title = Slim::Utils::Unicode::utf8decode_guess(Slim::Formats::XML::unescapeAndTrim($title));
					$desc  = Slim::Utils::Unicode::utf8decode_guess(Slim::Formats::XML::unescapeAndTrim($desc));

					if ($title && $href && $href =~ /\.ram$/) {

						push @streams, {
							'name'   => $title,
							'url'    => $href,
							'type'   => 'audio',
							'description' => $desc,
						};
					}
					
					$in_tr = 0;
					$in_mgrey = 0;
					$in_lgrey = 0;
					$title = '';
					$desc  = '';
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
