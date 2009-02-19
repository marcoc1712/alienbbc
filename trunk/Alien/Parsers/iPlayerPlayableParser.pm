#
# AlienBBC Copyright (C) Jules Taplin, Craig Eales, Triode, Neil Sleightholm, Bryan Alton 2004-2008
#
# $id: $
#
# This program is free software; you can redistribute it and/or 
# modify it under the terms of the GNU General Public License, version 2.
#
# Ipayer parses the episode details to get the playable streams.
#
package Plugins::Alien::Parsers::iPlayerPlayableParser;

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

sub getnext2tag
{
  my $t;
  my ($p,$searchtag,$endsearchtag) = @_;

  for (;;) {
     $t = $p->get_token();
     return undef unless (defined($t));
     return $t if ( $t->[1] eq $endsearchtag) ;
     return $t if ( $t->[1] eq $searchtag) ;

#     print "discard nexttag ". $t->[1]."\n";
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

    my $proghref;
    my $progtext;
    my $progdescr  = $params->{'item'}->{'description'} ;
    my $progimg;

	$log->info( "Playerable parsing $url");

	my $p = HTML::PullParser->new(api_version => 3, doc => ${$http->contentRef},
			      	    	  start => 'event, tag, attr,  skipped_text',
				    	  end   => 'event, tag, dtext, skipped_text',
				          report_tags => [qw ( a div ul img li p dl )]);

	my $t; 
	while (defined($t =  getnexttag($p,"div"))) {
		next if (!defined($t->[2]->{class} ));
		next if  ($t->[2]->{class} ne "semp-visual") ;
		last if (!defined ($t = getnexttag($p,"a")));
		$proghref= $t->[2]->{href};
#		$log->info( "found tag a url=$proghref");

		last if (!defined ($t = getnexttag($p,"/a")));
		last if (!defined ($t = getnexttag($p,"/p")));
		$progtext = $t->[3];
		$progtext =~ s/ to launch //;
		$progtext =~ s/ in Real Player.//;
		$log->info( "Prog text = \'$progtext\' URL=$proghref");

		last if (!defined ($t = getnexttag($p,"img")));
		if ((defined($t->[2]->{class} )) && ($t->[2]->{class} eq "semp-image-jsdisabled") ) {
			$progimg = $t->[2]->{src};
			$log->error("Progimg = $progimg");	
		}


		while (defined ($t = getnexttag($p,"div"))) {
			last if (!defined($t->[2]->{class} ));
			last if  (!defined ( $t->[2]->{class} ) && ($t->[2]->{class} ne "detail")) ;
			last if (!defined ($t = getnexttag($p,"dl")));
			$progdescr = $t->[3];
			$progdescr =~ s|<br />|\n|g;
		}

		if (defined($params->{'item'}->{'icon'})) {
			Plugins::Alien::RTSP::set_urlimg($proghref, $params->{'item'}->{'icon'});
		}
		else {
			Plugins::Alien::RTSP::set_urlimg($proghref, $progimg);
		}

		return {
			'type'  => 'opml',
			'items' => [ {
				'name' => Encode::decode_utf8($progtext),
				'url'  => $proghref,
				'type' => 'audio',
				'description' => Encode::decode_utf8( $progdescr),
				'icon' => $params->{'item'}->{'icon'},
			} ],
		};

	}
	return undef;
}
# Local Variables:
# tab-width:4
# indent-tabs-mode:t
# End:

1;
