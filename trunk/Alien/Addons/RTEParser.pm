#
# AlienBBC Copyright (C) Jules Taplin, Craig Eales, Triode, Neil Sleightholm, Bryan Alton 2004-2008
#
# $Id$
#
# This program is free software; you can redistribute it and/or 
# modify it under the terms of the GNU General Public License, version 2.
#
# AlienBBC support for the RTE (Ireland) radio (http://www.rte.ie)
#
package Plugins::Alien::Addons::RTEParser;

# Parser for DR menu menu pages

use strict;

use Slim::Utils::Log;

use HTML::PullParser;

my $log = logger('plugin.alienbbc');

sub parse 
{
	my ($title, $metatitle,$audiotitle,$videotitle,$entry);
	my ($starttime, $endtime);

	my $class  = shift;
	my $http   = shift;

	my $params = $http->params('params');
	my $url    = $params->{'url'};


	my $p = HTML::PullParser->new(doc => ${$http->contentRef},
						start => "event,tagname,attr", 
						report_tags => [qw ( audio video meta)]);
	while ( my $token = $p->get_token ) {

		if ( $token->[1] eq "meta") {
			$metatitle = $token->[2]->{content} if ( ($token->[2]->{name}) eq "title" );
			next;
		}

		$entry = $token->[2]->{src};
			if (!($entry =~ /^http:|rtsp:/)) {
			$log->info("RTEParser:    ignoring - non http: or rtsp: url\n");
			next;
		}

		if (defined ( $token->[2]->{title})) {
			if ($token->[1] eq "audio") {
				$audiotitle = $token->[2]->{title};
			} else {
				$videotitle = $token->[2]->{title};
			}
		}

		$starttime = $token->[2]->{begin}        if (defined( $token->[2]->{begin}));
		$starttime = $token->[2]->{clipbegin}    if (defined( $token->[2]->{clipbegin}));
		$starttime = $token->[2]->{"clip-begin"} if (defined( $token->[2]->{"clip-begin"}));
		$endtime   = $token->[2]->{end}          if (defined( $token->[2]->{end}));
		$endtime   = $token->[2]->{clipend}      if (defined( $token->[2]->{clipend}));
		$endtime   = $token->[2]->{"clip-end"}   if (defined( $token->[2]->{"clip-end"}));
	} 


	$starttime = normalise_time($starttime) if ($starttime ne "");
	$endtime   = normalise_time($endtime)   if ($endtime ne "");
	if ( $endtime ne "") {
		if ($starttime ne "") {
			$entry .= "?start=$starttime&end=$endtime";
		} else {
			$entry .= "?end=$endtime";
		}
	}
	elsif ($starttime ne "") {
		$entry .= "?start=$starttime";
	}

	$title = $audiotitle if defined ($audiotitle);
	$title = $audiotitle if defined ($videotitle);
	$title = $audiotitle if defined ($metatitle);
	$title = $params->{'feedTitle'} unless ( (defined ($title)) && ($title ne "RTE Publishing") );

	$log->info("RTEParser: Added SMIL playlist Title $title ($entry)");

	if (!$entry) {
		$log->warn("no url found for ($title ) " .  $params->{'feedTitle'} );
		return {};
	}

	$log->info("found url $entry for ($title ) " .  $params->{'feedTitle'} );
	return {
		'type'  => 'opml',
		'title' => "test $title",
		'items' => [ {
			'name' => $title,
			'url'  => $entry,
			'type' => 'audio',
		} ],
	};

}

sub normalise_time 
{
	my ($hrs,$mins,$secs,$decisecs) = (0,0,0,0);
	my $timestring = shift;

	if ($timestring =~m/("|)(\d+):(\d+):(\d+):(\d+\.?\d*)("|)$/){
		$hrs      = $3;
		$mins     = $4;
		$secs     = $5;
	}
	elsif ($timestring =~m/("|)(\d+):(\d+):(\d+\.?\d*)("|)$/){
		$hrs      = $2;
		$mins     = $3;
		$secs     = $4;
	}
	elsif ($timestring =~m/("|)(\d+):(\d+\.?\d*)("|)$/){
		$mins     = $2;
		$secs     = $3;
	}
	elsif ($timestring =~ m/("|)(\d+\.?\d*)("|)$/){
		$secs     = $2;
	}
	elsif ($timestring =~ m/("|)(\d+)("|)$/){
		$secs     = $2;
	} 
	elsif ($timestring =~ m/^("|)(\d+\.?\d*)(h|min|s|msec|)("|)$/) {
		my $units = $3;
		my $timevalue = $2;
		$timevalue =~m/(\d+)\.?(\d*)/;

		if ($units eq "h") {
			$hrs = $1;
			$mins = "0.$2" *60;
		} elsif ($units eq "min") {
			$mins = $1;
			$secs = "0.$2" *60;
		} elsif ($units eq "s") {
			$secs ="$1.$2"; 
		} else  {              # Millisec last valid choice
			$secs = $1/1000; 
		}
	}

	$secs =~m/(\d+)\.?(\d?)(\d*)/;
	$secs = $1;
	$decisecs = $2;

	if ($secs >= 60) {
		$mins = $mins + ($secs / 60);
		$secs = $secs % 60;
	}
	if ($mins >= 60) {
		$hrs = $hrs + ($mins / 60);
		$mins = $mins % 60;
	}

	return sprintf("%02d:%02d:%02d.%1d",$hrs, $mins, $secs, $decisecs );
}

# Local Variables:
# tab-width:4
# indent-tabs-mode:t
# End:

1;
