#
# AlienBBC Copyright (C) Jules Taplin, Craig Eales, Triode, Neil Sleightholm, Bryan Alton 2004-2008
#
# $Id$
#
# This program is free software; you can redistribute it and/or 
# modify it under the terms of the GNU General Public License, version 2.
#
# AlienBBC support for Wiki Radio http://wiki.slimdevices.com/plugin/attachments/WikiRadio/
#
package Plugins::Alien::Addons::WikiRadio;

use HTML::Parser;

sub parse {
	my $class = shift;
	my $http  = shift;

	my $params = $http->params('params');

	my @urls;
	my @entries;

    my $p = HTML::Parser->new(api_version => 3,
				start_h => [
					sub {
						my($tag,$attr) = @_;
						if ( $tag eq "a" ) {
							my $href = $attr->{"href"};
							push @urls, $href if $href =~ /.opml$/;
						}
					}, "tagname,attr"
				],
			);

	$p->parse(${$http->contentRef});

	foreach my $entry (@urls) {

		my $title = Slim::Utils::Misc::unescape($entry);
		my $url = $params->{'url'} . $entry;

		$title =~ s/\.opml//g; # remove .opml

		push @entries, {
			'name' => $title,
			'value'=> $url,
			'url'  => $url,
		};
	}

	# return xmlbrowser hash
	return {
		'type'  => 'opml',
		'title' => $params->{'feedTitle'},
		'items' => \@entries,
	};
}

1;
