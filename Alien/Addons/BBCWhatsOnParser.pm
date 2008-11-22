#
# AlienBBC Copyright (C) Jules Taplin, Craig Eales, Triode, Neil Sleightholm, Bryan Alton 2004-2008
#
# $Id$
#
# This program is free software; you can redistribute it and/or 
# modify it under the terms of the GNU General Public License, version 2.
#
# AlienBBC support for the BBC Whats On  items
#
package Plugins::Alien::Addons::BBCWhatsOnParser;

# Parser for BBC Whats's menu menu pages

use strict;

use Slim::Utils::Log;

use HTML::PullParser;
use HTML::Entities;


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
    $str =~ s/<br>//g; # Get rid of HTML <br> if any.
    $str =~ s/<br \/>//g; # Get rid of HTML <br> if any.
    $str =~ s/<BR>//g; # Get rid of HTML <BR> if any.
    $str =~ s/<B>//g; # Get rid of HTML <B> if any.
    $str =~ s/<\/B>//g; # Get rid of HTML </B> if any.
    $str =~ s/&nbsp;/ /g; # replace HTML &nbsp if any.

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
    my @list;

    my $token;
    my ( $txtime , $txname,  $txdesc);

    $log->info(" Entered BBC Whats On Url=$url");

    my $p = HTML::PullParser->new(api_version => 3, doc => ${$http->contentRef},
                                  start => 'event, tag, attr,  skipped_text',
                                  end   => 'event, tag, dtext, skipped_text',
                                  report_tags => [qw ( td tr table font)]);

    # get first table with Titles
    my $t = getnexttag($p,"table");
    $t = getnexttag($p,"tr");
    $t = getnexttag($p,"tr");
    $t = getnexttag($p,"tr");
    $t = getnexttag($p,"tr");
    $t = getnexttag($p,"td");
    $t = getnexttag($p,"font");
    $t = getnexttag($p,"/font");
    my $scheduledate = cleanup ($t->[3] ) ; 

    $t = getnexttag($p,"/td");
    $t = getnexttag($p,"td");
    $t = getnexttag($p,"font");
    $t = getnexttag($p,"/font");
    my $schedulechannel = cleanup ($t->[3] ) ;


    $t = getnexttag($p,"/td");
    $log->info(" BBC Whats On for $schedulechannel on $scheduledate");

    push @list, {'name'   =>  "$schedulechannel on $scheduledate" };

    # Get Table of program times

    $t = getnexttag($p,"table");
    while (defined($t)) {
        # Get a New Row
        $t = getnexttag($p,"tr");
        last if (!defined( $t)) ;
        $t = getnexttag($p,"td");

        # skip TD rows which are not the time.
        next if (!defined( $t->[2]->{width})) ;

        # Got a row Entry 
        $t = getnexttag($p,"font");
        $t = getnexttag($p,"/font");
        $txtime = cleanup ($t->[3] ) ;

        $t = getnexttag($p,"font");
        $t = getnexttag($p,"/font");
        $txname = cleanup ($t->[3] ) ;

        $t = getnexttag($p,"font");
        $t = getnexttag($p,"/font");
        $txdesc = cleanup ($t->[3] ) ;
        $log->info(" BBC Whats On  -> $txtime  $txname  $txdesc");

        push @list,{'name'   =>  "$txtime  $txname  $txdesc"};

        $t = getnexttag($p,"/td");
    }

    return {
        'type'  => 'opml',
        #'title' => $params->{'feedTitle'},
        'name' => "BBC Whats On - parsed",
        'items' => [ @list],
    };
}
# Local Variables:
# tab-width:4
# indent-tabs-mode:t
# End:

1;
