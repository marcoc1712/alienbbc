#
# AlienBBC Copyright (C) Jules Taplin, Craig Eales, Triode, Neil Sleightholm, Bryan Alton 2004-2008
#
# $Id$
#
# This program is free software; you can redistribute it and/or 
# modify it under the terms of the GNU General Public License, version 2.
#
# AlienBBC support for the BBC Podcast Radio stations items
#
package Plugins::Alien::Addons::BBCPodcastItemParser;

# Parser for BBC Podcast  menu menu pages

use strict;

use Slim::Utils::Log;
use Slim::Utils::Misc;

use HTML::PullParser;
use HTML::Entities;

my $log = logger('plugin.alienbbc');

sub getnexttag
{
    my $t;
    my $p         = shift;
    my $searchtag = shift;
    my $exittag   = shift;

    for (;;) {
        $t = $p->get_token();
        return undef unless (defined($t));
        return $t if ( $t->[1] eq $searchtag);
        return $t if ( defined ($exittag) && $t->[1] eq $exittag);
    }
}


sub cleanup
{
    my $str = shift;
    return undef unless defined ($str); 

    $str =~ s/\n/ /g;  # change LF to space
    $str =~ s/\r//g;   # Get rid of CR if any.

    $str =~ s/<br>//g; # Get rid of HTML <br> if any.
    $str =~ s/<br \/>//g; # Get rid of HTML <br> if any.

    $str =~ s/&nbsp;/ /g; # replace HTML &nbsp if any.

    $str =~ s/<h3>//g; # Get rid of HTML <h3> if any.
    $str =~ s/<h3\/>//g; # Get rid of HTML </h3> if any.

    # strip whitespace from beginning and end

    $str =~ s/^\s*//; 
    $str =~ s/\s*$//; 

    return $str;
}

sub parse
{
    my $class  = shift;
    my $http   = shift;

    my $params = $http->params('params');
    my $url    = $params->{'url'};
    my @podcasts;

    my $token;
    my $podcasthref;
    my $podcastname;
    my $podcastdesc;
    my $podcastfileinfo;

    $log->info(" Parsing BBC Podcast Url=$url");

    my $p = HTML::PullParser->new(api_version => 3, doc => ${$http->contentRef},
                                  start => 'event, tag, attr,  skipped_text',
                                  end   => 'event, tag, dtext, skipped_text',
                                  report_tags => [qw ( h3 h2 a p div)]);

    while($token = getnexttag($p,"div")) {
        next unless defined($token->[2]->{class});
        last if $token->[2]->{class} eq "grouped clearme";
    }
    return unless defined($token);

    while($token = getnexttag($p,"h2")) {
        $token = getnexttag($p,"/h2");
        last if (($token->[3] eq "Latest Episode") || ($token->[3] eq "Latest Episodes"));
    }
    return unless (defined($token));
    
    while (defined($token)) {
        $token = getnexttag($p,"h3");
        last unless (defined( $token));
        $token = getnexttag($p,"/h3");
        $podcastname = HTML::Entities::decode_entities(cleanup ($token->[3]));

        $token = getnexttag($p,"p");
        last unless (defined( $token));
        if ($token->[2]->{class} eq "description") {
            $token = getnexttag($p,"/p");
            $podcastdesc = HTML::Entities::decode_entities(cleanup ($token->[3]));
        }
        last unless (defined( $token));

        $token = getnexttag($p,"p");
        last unless (defined( $token));
        if ($token->[2]->{class} eq "fileinfo") {
            $token = getnexttag($p,"/p");
            $podcastfileinfo = HTML::Entities::decode_entities(cleanup ($token->[3]));
        }
        last unless (defined( $token));

        $token = getnexttag($p,"p");
        last unless (defined( $token));
        if ($token->[2]->{class} eq "download") {
            $token = getnexttag($p,"a");
            $podcasthref= $token->[2]->{href} if( defined $token->[2]->{href});
        }
        last unless (defined ($podcasthref));

        $log->info("Adding entry - Name=$podcastname href=$podcasthref  Desc=$podcastdesc");
		
        push @podcasts, {
            'name' => $podcastname . $podcastdesc,
            'url'  => $podcasthref,
            'type' => 'audio',
            'description' => $podcastdesc
        };
    };

    return {
        'type'  => 'opml',
        'items' => [@podcasts],
    };
}

# Local Variables:
# tab-width:4
# indent-tabs-mode:t
# End:

1;


