#
# AlienBBC Copyright (C) Jules Taplin, Craig Eales, Triode, Neil Sleightholm, Bryan Alton 2004-2008
#
# $Id$
#
# This plugin is free software; you can redistribute it and/or modify it 
# under the terms of the GNU General Public License, version 2.
#
package Plugins::Alien::Playlists::SMIL;

use strict;
use base qw(Slim::Formats::Playlists::Base);

use HTML::PullParser;

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

    my $metatitle;
    my ($starttime,$endtime);

    my $ignore = join '|',  @{$prefs->get('ignore')}; # paterns in urls to ignore

    $log->info("Ignoring: $ignore");
    $log->info("parsing rtsp SMIL playlist: $list");

    my $listname = Slim::Music::Info::title($list);
    my $p        = HTML::PullParser->new(file => $pl ,start => "event,tagname,attr", report_tags => [qw(audio video meta)]);

    while ( my $token = $p->get_token ) {
        my $title;
        if ( $token->[1] eq "meta") {
            # print " Name =  " . $token->[2]->{name} . "Content =". $token->[2]->{content} . "\n";
            $metatitle = $token->[2]->{content} if ( ($token->[2]->{name}) eq "title" );
            next;
        }

        # Here if a audio or video source
        my $entry = $token->[2]->{src};

        if (!($entry =~ /^http:|rtsp:/)) {
            $log->info("    ignoring - non http: or rtsp: url");
            next;
        }
        if ($ignore && $entry =~ /$ignore/) {
            $log->info("    ignoring - matches ignore pattern");
            next;
        }
        $count = scalar(@items) + 1;
        $log->info("    entry $count: $entry");
        # Append the count if there is more than one stream
        if (defined ( $token->[2]->{title})) {
            $title  = $token->[2]->{title};
        } else {
            if (defined($metatitle)) {
                $title = $metatitle;
            }
            else {
                $title = $listname;
            } 
            $title .= " [$count]" if ($count > 1);
        }
        # Add starttime / endtime if present in audio or video tag - 
        $starttime = ""; $endtime = "";
        $starttime = $token->[2]->{begin}        if (defined( $token->[2]->{begin}));
        $starttime = $token->[2]->{clipbegin}    if (defined( $token->[2]->{clipbegin}));
        $starttime = $token->[2]->{"clip-begin"} if (defined( $token->[2]->{"clip-begin"}));
        $endtime   = $token->[2]->{end}          if (defined( $token->[2]->{end}));
        $endtime   = $token->[2]->{clipend}      if (defined( $token->[2]->{clipend}));
        $endtime   = $token->[2]->{"clip-end"}   if (defined( $token->[2]->{"clip-end"}));

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

        $log->info("Added SMIL playlist Title $title ($entry)");
        push @items, $class->_updateMetaData($entry, { TITLE => $title } );
    }

    $log->info("parsed " . scalar(@items) . " items in rtsp SMIL playlist");

    return @items;
}

sub normalise_time {

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

1;
