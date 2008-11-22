#
# AlienBBC Copyright (C) Jules Taplin, Craig Eales, Triode, Neil Sleightholm, Bryan Alton 2004-2008
#
# $Id$
#
# This program is free software; you can redistribute it and/or 
# modify it under the terms of the GNU General Public License, version 2.
#
# AlienBBC support for the Denmark radio (http://www.dr.dk/netradio/afspillere.asp)
#
package Plugins::Alien::Addons::DRParser;

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
        return $t if ( defined ($exittag) && $t->[1] eq $exittag) ;
    }
}

sub cleanup
{
    my $str = shift;
    return undef unless defined ($str); 
  
    $str =~ s/\n/ /g;  # change LF to space
    $str =~ s/\r//g;   # Get rid of CR if any.
    # $str =~ s/<br>//g; # Get rid of HTML <br> if any.
    # $str =~ s/<br \/>//g; # Get rid of HTML <br> if any.
    # $str =~ s/<big>//g; # Get rid of HTML <big> if any.
    # $str =~ s/<\/big>//g; # Get rid of HTML </big> if any.
    # $str =~ s/<BR>//g; # Get rid of HTML <BR> if any.
    # $str =~ s/<B>//g; # Get rid of HTML <B> if any.
    # $str =~ s/<\/B>//g; # Get rid of HTML </B> if any.
    $str =~ s/&nbsp;/ /g; # replace HTML &nbsp if any.
    $str =~ s/<strong>/ /g; # replace HTML &nbsp if any.
    $str =~ s/<\/strong>/ /g; # replace HTML &nbsp if any.

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

    my @menus;
    my @streams;
    my %stations;

    my $p = HTML::PullParser->new(api_version => 3, doc => ${$http->contentRef},
                                  start => 'event, tag, attr,  skipped_text',
                                  end   => 'event, tag, dtext, skipped_text',
                                  report_tags => [qw ( a td tr table )]);

    # Get the table of radio stations
    my $t = getnexttag($p,"table");
    # Skip "Kanal" heading
    $t = getnexttag($p,"tr");
    
    while (defined($t)) {
        # Get a New Row
        $t = getnexttag($p,"tr");
        last if (!defined( $t)) ;
        # Channel name first
        $t = getnexttag($p,"td");
        $t = getnexttag($p,"/td");
        my $channelname = HTML::Entities::decode_entities(cleanup ($t->[3] )) ; 

        $t = getnexttag($p,"td");
        # For each channel - parse multiple <A>...</A> one for each quality level
        while (defined ($t) ) {
            $t = getnexttag($p,"a","/td");
            last if ($t->[1] eq "/td");
            my $href = $t->[2]->{href};
            $t = getnexttag($p,"/a");
            my $quality = HTML::Entities::decode_entities(cleanup ($t->[3]));    
            $log->info("DRRadio added channel $channelname quality: $quality url $href");
            push @{$stations{$quality}}, {
                        'name'   => "$channelname",
                        'url'    => $href,
                        'type'   => 'audio',
#                        'type'   => 'playlist',
                    };
        }
    }

    foreach my $quality (keys %stations) {

         my $items = $stations{$quality};

        $log->info("DRRadio added menu quality: $quality");

         push @menus ,    {
            'type'  => 'opml',
            'name' => $quality,
            'items' => [ @{$stations{$quality}}],
                
        };
    }

    my @streams = @{$stations{"Lav"}};

    return {
        'type'  => 'opml',
#        'title' => $params->{'feedTitle'},
        'name' => "Denmarks Radio",
        'items' => [ @menus, @streams],
    };
}
# Local Variables:
# tab-width:4
# indent-tabs-mode:t
# End:

1;
