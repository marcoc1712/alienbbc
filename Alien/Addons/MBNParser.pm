#
# AlienBBC Copyright (C) Jules Taplin, Craig Eales, Triode, Neil Sleightholm, Bryan Alton 2004-2008
#
# $Id$
#
# This program is free software; you can redistribute it and/or 
# modify it under the terms of the GNU General Public License, version 2.
#
# AlienBBC support for the Moody Broadcast Network (http://www.mbn.org)
#
package Plugins::Alien::Addons::MBNParser;

# Parser for MBN stations

use strict;

use Slim::Utils::Log;

use HTML::PullParser;

my $log = logger('plugin.alienbbc');

sub getnexttag
{
    my $t;
    my $p         = shift;
    my $searchtag = shift;
    my $exittag   = shift ;
    
    for (;;) {
        $t = $p->get_token();
        return undef unless (defined($t));
        return $t if ( $t->[1] eq $searchtag) ;
        return $t if ( defined ($exittag) && $t->[1] eq $exittag);
    }
}

sub parse
{
    my $class  = shift;
    my $http   = shift;

    my $params = $http->params('params');
    my $url    = $params->{'url'};

    my $progurl;
    my $progdate;
    my @broadcasts;

    my $p = HTML::PullParser->new(api_version => 3, doc => ${$http->contentRef},
                                  start => 'event, tag, attr,  skipped_text',
                                  end   => 'event, tag, dtext, skipped_text',
                                  report_tags => [qw ( a )]);

    # Get the table of radio stations
    for(;;) {
        my $t = getnexttag($p,"a");
        last unless defined($t);
        next unless exists $t->[2]->{href};
        $log->debug("MBNParser: found A tag with href " . $t->[2]->{href} );

        if( $t->[2]->{href} =~ m"\A/GenMoody/default.asp\?sectionID") {    
            $log->info("MBNParser: found url $progurl for ($progdate ) " .  $params->{'feedTitle'} );
            $progurl = "http://www.mbn.org" . $t->[2]->{href};
            $t = getnexttag($p,"/a");
            $progdate = $t->[3];
            push @broadcasts, {
                'name'   => "$progdate",
                'url'    => $progurl,
                'parser' => 'Plugins::Alien::Addons::MBNPlayableParser',
                'type'   => 'playlist',
            };
        }
    }
    if (!defined($progurl) ) {
        $log->warn("no url found for " . $params->{'feedTitle'});
        return {};
    }
    $log->info("MBNParser: found url $progurl for ($progdate ) " .  $params->{'feedTitle'} );

    return {
        'type'  => 'opml',
        'name' => $params->{'feedTitle'},
        'items' => [ @broadcasts],
    };
}

# Local Variables:
# tab-width:4
# indent-tabs-mode:t
# End:

1;
