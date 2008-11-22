#
# AlienBBC Copyright (C) Jules Taplin, Craig Eales, Triode, Neil Sleightholm, Bryan Alton 2004-2008
#
# $Id$
#
# This plugin is free software; you can redistribute it and/or modify it 
# under the terms of the GNU General Public License, version 2.
#
# Parser for Aod menu pages
#
package Plugins::Alien::Parsers::AodParser;

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

	my @menus;
	my @streams;
	my $redirect;

	my $title = '';
	my $desc  = '';
	my $last  = '';
	my $in_a;
	my $in_bbcradio;
	my $in_bbcplayer;
	my $in_shows;
	my $href;

	my $p = HTML::Parser->new(api_version => 3,
		start_h => [
			sub {
				my $tag = shift;
				my $attr = shift;

				if ($tag eq 'frame' && $attr->{'name'} =~ /channel|shows/) {
					$redirect = fixupUrl($attr->{'src'}, $url);
				}

				if ($tag eq 'a' && $attr->{'target'} =~ /^(bbcradio|bbcplayer|shows)$/) {

 					$in_bbcradio  = 1 if ($attr->{'target'} eq 'bbcradio');
					$in_bbcplayer = 1 if ($attr->{'target'} eq 'bbcplayer');
					$in_shows     = 1 if ($attr->{'target'} eq 'shows');

					$href = $attr->{'href'};
					$title = '';
					$desc  = '';
					$in_a  = 1;
				}
			},
			"tagname,attr"
		],
		text_h => [
			sub {
				my $t = shift;

				if ($in_a) {
					$title .= $t;
				} else {
					$desc  .= $t;
				}
			},
			"text"
		],
		end_h => [
			sub {
				my $tag = shift;

				return unless ($in_bbcradio || $in_bbcplayer || $in_shows);

				$href  = fixupUrl($href, $url);
				$title = Slim::Utils::Unicode::utf8decode_guess(Slim::Formats::XML::unescapeAndTrim($title));
				$desc  = Slim::Utils::Unicode::utf8decode_guess(Slim::Formats::XML::unescapeAndTrim($desc));

				if (($in_bbcradio || $in_shows) && $title) {

					push @menus, {
						'name'   => $title,
						'url'    => $href,
						'parser' => 'Plugins::Alien::Parsers::AodParser',
					};
				}

				if ($in_bbcplayer && $title !~ /^(Low|High)$/) {

					if ($title =~ /^(MON|TUE|WED|THU|FRI|SAT|SUN)$/i) {
						$title = "$last - $title";
						$desc  = '';
					} else {
						$last = $title;
					}

					$title =~ s/(^LW$|^FM$)/$params->{'feedTitle'} $1/;
					$title =~ s/listen live/$params->{'feedTitle'} Listen Live/i;
					$title =~ s/real player//i;
					$desc  =~ s/- //i;

					push @streams, {
						'name'   => $title,
						'url'    => $href,
						'parser' => 'Plugins::Alien::Parsers::PlayableAodParser',
						'type'   => 'playlist',
						'description' => $desc,
					};
				}

				$in_bbcradio = 0;
				$in_bbcplayer = 0;
				$in_shows = 0;
				$in_a  = 0;
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

	$log->info(sprintf "found %d streams and %d menus", scalar @streams, scalar @menus);

	# return xmlbrowser hash
	return {
		'type'  => 'opml',
		'title' => $params->{'feedTitle'},
		'items' => [@streams, @menus],
	};
}

1;
