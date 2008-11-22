#
# AlienBBC Copyright (C) Jules Taplin, Craig Eales, Triode, Neil Sleightholm, Bryan Alton 2004-2008
#
# $Id$
#
# This program is free software; you can redistribute it and/or 
# modify it under the terms of the GNU General Public License, version 2.
#
# AlienBBC support for the Prarie Home Companio radio (http://prairiehome.publicradio.org/programs)
#
package Plugins::Alien::Addons::NPRPrarieParser;

# Parser for NPR Prarie Home Companion menu pages

use strict;

use Slim::Utils::Log;

use HTML::PullParser;

my $log = logger('plugin.alienbbc');

sub parse
{
	my $class  = shift;
	my $http   = shift;

	my $params = $http->params('params');
	my $url    = $params->{'url'};

	my @itemlist;

	my $p = HTML::PullParser->new(api_version => 3, doc => ${$http->contentRef},
		      	    	  start => 'event, tag, attr,',
			          report_tags => [qw ( a )]);

	while ( my $token = $p->get_token ) {
		next unless $token->[1] eq "a";
		next unless defined ($token->[2]->{href});

#         http://prairiehome.publicradio.org/programs/2006/01/28/index.shtml
		if( $token->[2]->{href} =~ m"\Ahttp://prairiehome.publicradio.org/programs/(\d+)/(\d+)/(\d+)/index.shtml\z") {
			my $progname = sprintf("Prarie Home companion  %04d/%02d/%02d ",$1,$2,$3);
		        my $progurl = sprintf( "http://www.publicradio.org/tools/media/player/phc/%04d/%02d/%02d_phc.smil",$1,$2,$3);
			push @itemlist, {
					'name'   => "$progname",
					'url'    => $progurl,
					'type'   => 'audio',
					};
			last if (scalar (@itemlist) > 10);
		}
	}

	if ( scalar (@itemlist) == 0) {
		$log->info("Prarie praser found no entries ");
		return {};
	}

	$log->info (" PrarieParser returning ". scalar (@itemlist) . " entries ");
	return {
 		'type'  => 'opml',
		'name' => $params->{'feedTitle'},
		'items' => [ @itemlist],
	};
}

# Local Variables:
# tab-width:4
# indent-tabs-mode:t
# End:

1;
