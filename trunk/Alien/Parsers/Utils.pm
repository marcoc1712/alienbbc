#
# AlienBBC Copyright (C) Jules Taplin, Craig Eales, Triode, Neil Sleightholm, Bryan Alton 2004-2008
#
# $Id$
#
# This plugin is free software; you can redistribute it and/or modify it 
# under the terms of the GNU General Public License, version 2.
#
package Plugins::Alien::Parsers::Utils;

use Exporter::Lite;

our @EXPORT = qw(fixupUrl);

sub fixupUrl
{
	my $dest = shift;
	my $orig = shift;

	if ($dest =~ /^\//) {

		$dest = "http://www.bbc.co.uk" . $dest;

	} elsif ($dest =~ /^http:/) {


	} else {
		my $path;
		($path) = $orig =~ /(.*)\/(.*?)/;
		$dest = $path."/".$dest;
		#print "FixUpUrl: Prepending directory to relative URL (yielding: ".$dest.")\n";
	}

	return $dest;
}

1;
