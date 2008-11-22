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
package Plugins::Alien::Addons::BBCPodcastParser;

# Parser for BBC Podcast  menu menu pages

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

        $str =~ s/&nbsp;/ /g; # replace HTML &nbsp if any.

    $str =~ s/<h3>//g; # Get rid of HTML <h3> if any.
    $str =~ s/<\/h3>//g; # Get rid of HTML </h3> if any.

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
    my $stationhref;
    $log->info(" Entered BBC Podcast Url=$url");

    my $p = HTML::PullParser->new(api_version => 3, doc => ${$http->contentRef},
                                  start => 'event, tag, attr,  skipped_text',
                                  end   => 'event, tag, dtext, skipped_text',
                                  report_tags => [qw ( div a li p)]);

    while($token = getnexttag($p,"div")) {
        next unless defined($token->[2]->{id});
        last if $token->[2]->{id} eq "results_cells";
    }
    $log->info(" Found start of podcasts table ") if (defined($token));

    while (    $token = getnexttag($p,"div")) {
        next unless defined($token->[2]->{class});
        next unless $token->[2]->{class} eq "headline clearme";
        # Found a new podcast cell
        $token = getnexttag($p,"a");
        last if (!defined( $token)) ;
        my $podcasthref = $token->[2]->{href};

        $token = getnexttag($p,"/a");
        last if (!defined( $token)) ;
        my $podcastname = HTML::Entities::decode_entities(cleanup ($token->[3]));        

        $token = getnexttag($p,"li");
        last if (!defined( $token)) ;
        $token = getnexttag($p,"/li");
        my $stationname = HTML::Entities::decode_entities(cleanup ($token->[3]));        

        $token = getnexttag($p,"li");
        last if (!defined( $token)) ;
        $token = getnexttag($p,"/li");
        my $podcastcategory = HTML::Entities::decode_entities(cleanup ($token->[3]));        

        $token = getnexttag($p,"li");
        last if (!defined( $token)) ;
        $token = getnexttag($p,"/li");
        my $podcastduration = HTML::Entities::decode_entities(cleanup ($token->[3]));        
        if ($podcastduration =~ m/Typical Duration: (.*)$/) {
            $podcastduration = $1;
        }
        $token = getnexttag($p,"li");
        last if (!defined( $token)) ;
        $token = getnexttag($p,"/li");
        my $podcastdate = HTML::Entities::decode_entities(cleanup ($token->[3]));        
        if ($podcastdate =~ m/Latest Episode: (.*)$/) {
          $podcastdate = $1;
        }
# Restrictions li entry
        $token = getnexttag($p,"li");
        last if (!defined( $token)) ;
	my $podcastrestriction =  ($token->[2]->{class} eq 'restrictions ukonly') ? '(UK only)' : '';
        $token = getnexttag($p,"/li");

        $token = getnexttag($p,"p");
        last if (!defined( $token)) ;
        $token = getnexttag($p,"/p");
        my $podcastlongtext = HTML::Entities::decode_entities(cleanup ($token->[3]));        

        $log->info("Adding Podcast Name: $podcastname $podcastrestriction URL=$podcasthref Duration=$podcastduration Category=$podcastcategory Date=$podcastdate  Long desc=$podcastlongtext");
		if ( $podcastdate ne 'none' ) {
        	push @podcasts, {
                    'name'   => "$podcastname $podcastrestriction $podcastlongtext  $podcastdate ($podcastduration)",    
                    'url'    => "http://www.bbc.co.uk" . $podcasthref,
                    'parser' => 'Plugins::Alien::Addons::BBCPodcastItemParser',
                    'type'   => 'playlist',
                    'description'   => "$podcastname $podcastrestriction $podcastlongtext  $podcastdate ($podcastduration)" ,

                };
    	} else {
		        $log->info("Omitting Podcast Name: $podcastname   No podcast as podcast date was none");
    	};	
    }

    return {
        'type'  => 'opml',
        # 'title' => $params->{'feedTitle'},
        'name' => "BBC Podcasts - parsed",
        'items' => [ @podcasts],
    };
}

# Local Variables:
# tab-width:4
# indent-tabs-mode:t
# End:

1;


