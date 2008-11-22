#
# AlienBBC Copyright (C) Jules Taplin, Craig Eales, Triode, Neil Sleightholm, Bryan Alton 2004-2008
#
# $Id$
#
# This program is free software; you can redistribute it and/or 
# modify it under the terms of the GNU General Public License, version 2.
#
# AlienBBC support for the ABC Podcast items
#
package Plugins::Alien::Addons::ABCPodcastParser;

# Parser for ABC Podcast  menu menu pages

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
    # $str =~ s/<big>//g; # Get rid of HTML <big> if any.
    # $str =~ s/<\/big>//g; # Get rid of HTML </big> if any.
    # $str =~ s/<BR>//g; # Get rid of HTML <BR> if any.
    # $str =~ s/<B>//g; # Get rid of HTML <B> if any.
    # $str =~ s/<\/B>//g; # Get rid of HTML </B> if any.
    $str =~ s/&nbsp;/ /g; # replace HTML &nbsp if any.
    # $str =~ s/<strong>/ /g; # replace HTML &nbsp if any.
    # $str =~ s/<\/strong>/ /g; # replace HTML &nbsp if any.
    $str =~ s/<small>/ /g; # replace HTML <small> if any.
    $str =~ s/<\/small>/ /g; # replace HTML </small> if any.

    # strip whitespace from beginning and end

    $str =~ s/^\s*//; 
    $str =~ s/\s*$//; 

    return $str;
}

my @podcasts;

sub parse
{
    my $class  = shift;
    my $http   = shift;

    my $params = $http->params('params');
    my $url    = $params->{'url'};

    my $token;
    $log->info(" Entered ASBC Podcast");

    my $p = HTML::PullParser->new(api_version => 3, doc => ${$http->contentRef},
                                  start => 'event, tag, attr,  skipped_text',
                                  end   => 'event, tag, dtext, skipped_text',
                                  report_tags => [qw ( div a p)]);

    while($token = getnexttag($p,"div")) {
        $log->info("Looking for mainColumn ") ;

        next unless defined($token->[2]->{id});
        last if $token->[2]->{id} eq "mainColumn";
    }
    $log->info(" Found mainColumn ") if (defined($token));

    # Get the table of radio stations - each entry is a <div class="program">
    $token = getnexttag($p,"div");
    while (    $token = getnexttag($p,"div")) {
        $log->info(" Top of Podcast loop - new program");

        next unless defined($token->[2]->{class});
        next unless $token->[2]->{class} eq "program";
        # Get a Podcast URL
        $token = getnexttag($p,"a");
        last if (!defined( $token)) ;

        $token = getnexttag($p,"/a");
        my $podname = HTML::Entities::decode_entities(cleanup ($token->[3]));    
        $log->info(" Podname = >>$podname<<");

        # skip one <a>
        $token = getnexttag($p,"a");
        last if (!defined( $token)) ;

        $token = getnexttag($p,"p");
        last if (!defined( $token)) ;
        my $poddesc = HTML::Entities::decode_entities(cleanup ($token->[3]));    
        $log->info(" Poddesc = >>$poddesc<<");
        # This should be real podcast XML URL
        $token = getnexttag($p,"a");
        last if (!defined( $token)) ;
        next unless defined($token->[2]->{class});
        next unless $token->[2]->{class} eq "pod";
        my $href = $token->[2]->{href};
        $log->info(" Pod href = >>$href<<");

        push @podcasts, {
                    'name'   => $podname,
                    'url'    => $href,
                    #'type'   => 'audio',
                    'type'   => 'playlist',
                };
        
    }

    return {
        'type'  => 'opml',
         #'title' => $params->{'feedTitle'},
        'name' => "ABC Podcasts - parsed",
        'items' => [ @podcasts],
    };
}

# Local Variables:
# tab-width:4
# indent-tabs-mode:t
# End:

1;
