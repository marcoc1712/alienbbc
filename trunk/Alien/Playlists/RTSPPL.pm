#
# AlienBBC Copyright (C) Jules Taplin, Craig Eales, Triode, Neil Sleightholm, Bryan Alton 2004-2008
#
# $Id$
#
# This plugin is free software; you can redistribute it and/or modify it 
# under the terms of the GNU General Public License, version 2.
#
package Plugins::Alien::Playlists::RTSPPL;

use strict;
use base qw(Slim::Formats::Playlists::Base);

use Socket qw(:crlf);

use Slim::Music::Info;
use Slim::Utils::Misc;
use Slim::Utils::Prefs;
use Slim::Utils::Log;

my $log = logger('plugin.alienbbc');

my $prefs = preferences('plugin.alienbbc');

sub read {
    my ($class, $pl, undef, $list) = @_;
    my @items  = ();
    my $count = 0;

    my $ignore = join '|', @{$prefs->get('ignore')}; # paterns in urls to ignore

    $log->info("Ignoring: $ignore");
    $log->info("parsing rtsp playlist: $list");

    while (defined($pl) && (my $entry = <$pl>)) {

        chomp($entry);

        # strip carriage return from dos playlists
        $entry =~ s/\cM//g;  

        # strip whitespace from beginning and end
        $entry =~ s/^\s*//; 
        $entry =~ s/\s*$//; 

        $log->info("  entry from file: $entry");

        if (!($entry =~ /^http:|rtsp:/)) {
            $log->info("    ignoring - non http: or rtsp: url");
            next;
        }

        if ($ignore && $entry =~ /$ignore/) {
            $log->info("    ignoring - matches ignore pattern");
            next;
        }

        if ($entry =~ /^<(.*)\/>/ && $entry =~ /(\")(.*)(\")/ ) { 
            $entry = $2;
        }

        $entry =~ s|$LF||g;
		$entry =~ s/ /%20/g; # cater for corrupt urls with spaces (e.g. radio 5)

        $count = scalar(@items) + 1;
        $log->info("    entry $count: $entry");

        my $title = Slim::Music::Info::title($list);

        # Append the count if there is more than one stream
        $title .= " [$count]" if ($count > 1);

        push @items, $class->_updateMetaData($entry, { TITLE => $title } );
    }

    $log->info("parsed " . scalar(@items) . " items in rtsp playlist");

    return @items;
}

1;

# Local Variables:
# tab-width:4
# indent-tabs-mode:t
# End:
