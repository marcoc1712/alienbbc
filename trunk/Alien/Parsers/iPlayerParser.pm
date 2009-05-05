#
# AlienBBC Copyright (C) Jules Taplin, Craig Eales, Triode, Neil Sleightholm, Bryan Alton 2004-2008
#
# $id: $
#
# This program is free software; you can redistribute it and/or 
# modify it under the terms of the GNU General Public License, version 2.
# 
# PiPlayer parser - parses the main top level Radio pages which have a table of programs/episodes.
#
package Plugins::Alien::Parsers::iPlayerParser;

use strict;

use Slim::Utils::Log;

use HTML::PullParser;

my $log = logger('plugin.alienbbc');

use Data::Dumper;

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
  }
}

sub cleanup
{
    my $str = shift;
    return undef unless defined ($str); 

    $str =~ s/\n/ /g;  # change LF to space
    $str =~ s/\r//g;   # Get rid of CR if any.

    $str =~ s/<br>//gi; # Get rid of HTML <br> if any.
    $str =~ s/<br \/>//gi; # Get rid of HTML <br> if any.

        $str =~ s/&nbsp;/ /g; # replace HTML &nbsp if any.

    $str =~ s/<h3>//gi; # Get rid of HTML <h3> if any.
    $str =~ s/<\/h3>//gi; # Get rid of HTML </h3> if any.

    $str =~ s/<span>//gi; # Get rid of HTML <h3> if any.
    $str =~ s/<\/span>//gi; # Get rid of HTML </h3> if any.

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
    my $client = $params->{client};

    my $topmenu      = defined( $params->{'item'}->{'topmenu'}); 
    my $schedulemenu = defined( $params->{'item'}->{'schedule'}); 

    my @menus;
    my $submenu;
    my $savedstreams;
    my %stations;
    my $menuname;
    my $topmenus;

    my $progclass;
    my $progsetitle;
    my $progeptitle;
    my $progurl;
    my $progdesc;
    my $progstack;
    my $progimg;
    my $otherepstitle;
    my $progtime;

    my $t;
    my $currentpage;
    my $totalpages;
    my $pageofpages;
    my %pageurls;

#
#  If BBC have defined the iPlayer url not to be cached - this causes big delay as XML.pm will not cache XML parsed result if cachtime=0 
#  so - iPlayer pages will be cached for 5 mins (300 secs) regardless of BBC wishes.

    if (( defined ($http->cacheTime) ) && ($http->cacheTime == 0) ) {
		$http->cacheResponse(300);
    }

    my $p = HTML::PullParser->new(api_version => 3, doc => ${$http->contentRef},
                                  start => 'event, tag, attr,  skipped_text',
                                  end   => 'event, tag, dtext, skipped_text',
                                  report_tags => [qw (  a img span h1 h3 div p ul li ol )]);

# If a top menu as defined in opml - look for categores and Schedule.
# <ul id="nav-categories" class="service-categories">

	if ($topmenu ) {
		my $itemname;
		my $itemurl;

		$p->report_tags(qw(a ul li));

		while (defined($t =  getnexttag($p,"ul"))) {
			next if (!defined ($t->[2]->{id}));
			last if  ($t->[2]->{id} eq "nav-schedule") ;
		}

		while(defined($t = getnext2tag($p,"li","/ul"))) {
			last if ($t->[1] eq "/ul");
			$t = getnext2tag($p,"a","/li");
			next if ($t->[1] eq "/li");
			next if (!defined($t->[2]->{href}));
			$itemurl = $t->[2]->{href};
			last if (!defined ($t = getnexttag($p,"/a")));
			$itemname = cleanup($t->[3]);
			$itemname =~ s/\s+\(/ \(/;
			$log->info("schedule item $itemname");

#			last if ($itemname =~ m/(tomorrow)/i);
			next if (! ($itemname =~ m/^(Mon |Tues |Wed |Thurs |Fri |Sat |Sun )/i));

			push @$submenu, {
				'name'   => $itemname,
				'url'    => 'http://www.bbc.co.uk' . $itemurl,
				'parser' => 'Plugins::Alien::Parsers::iPlayerParser',
				'schedule' => '1', 
				};
		}
		$p->report_tags(qw (  a img span h1 h3 div p ul li ol ));

		if (defined($submenu )) {
			$log->info(sprintf "found %d schedule streams on url %s", scalar @$submenu,$url);

			push @$topmenus, {
				'name'   => 'Schedule',
				'items'  => \@$submenu,
				'type'   => 'opml',
				'icon'   => "http://radiotime-logos.s3.amazonaws.com/a33829q.png",
				};	
			$submenu = undef;
		}

		while (defined($t =  getnexttag($p,"ul"))) {
			next if (!defined ($t->[2]->{id}));
			last if  ($t->[2]->{id} eq "nav-categories") ;
		}

#	return if (!defined($t));
		while(defined($t = getnext2tag($p,"a","/ul"))) {
			last if ($t->[1] eq "/ul");
			next if (!defined($t->[2]->{href}));
			$itemurl = $t->[2]->{href};
			last if (!defined ($t = getnexttag($p,"/a")));
			$itemname = $t->[3];
			$log->info("category item $itemname");

			push @$submenu, {
				'name'   => $itemname,
				'url'    => 'http://www.bbc.co.uk' . $itemurl,
				'parser' => 'Plugins::Alien::Parsers::iPlayerParser',
				};
		}

		if (defined($submenu )) {
			$log->info(sprintf "found %d categories on url %s", scalar @$submenu,$url);

			push @$topmenus, {
				'name'   => 'Categories',
				'items'  => \@$submenu,
				'type'   => 'opml',
				'icon'   => "http://radiotime-logos.s3.amazonaws.com/a33829q.png",
				};	
			$submenu = undef;
		}
	}

	while (defined($t =  getnexttag($p,'div'))) {
		next if (!defined ($t->[2]->{id}));
		last if  ($t->[2]->{id} eq "results-header") ;
	}
		$log->info( "Found results-header ");

	$t =  getnexttag($p,'h1');
	$t =  getnexttag($p,'/h1');
	$menuname= $t->[3];

	
	while (defined($t =  getnexttag($p,'div'))) {
		next if (!defined ($t->[2]->{id}));
		last if  ($t->[2]->{id} eq "listview") ;
	}

# <ol id="page-selection" class="page-selection">
	$t =  getnext2tag($p,'ol','div');
	if ($t->[1] eq 'ol') {
		return undef unless (defined($t) && defined($t->[2]->{id}));
		my $searchcurrentpage = undef;
		my $searchtotalpages  = undef;	
		while (defined($t =  getnext2tag($p,"li","div"))) {
			last if ($t->[1] eq "div");

			if (( defined($t->[2]->{class}) ) && ($t->[2]->{class} eq "current-page" )  ) {
				$t = getnexttag($p,"/li");
				$searchcurrentpage = int($t->[3] );
				$log->debug("Search results current page=$searchcurrentpage");
				next;
			}
			$t =  getnexttag($p,"a");

			my $page = $t->[2]->{class};
			my $href = $t->[2]->{href};
			$t =  getnexttag($p,"/a");
			$pageurls{lc($t->[3])} = $href;

			if ($page =~ m/last /) {
				$searchtotalpages = int($t->[3])  ;
				$log->debug("Found last page in \'$page\' currentpage=$searchcurrentpage totalpages=$searchtotalpages (". $t->[3].") ");
				$t = getnexttag($p,"div");
				last;
			}
		}
		$totalpages = (defined($searchtotalpages)) ? $searchtotalpages : $searchcurrentpage;
		$currentpage = $searchcurrentpage;
		$log->debug ("Processed page nos $totalpages $currentpage");

	}
	else {
		$totalpages = 1;
		$currentpage = 1;
		$log->debug ("No page listing");

	}

	if ($currentpage == 1) {
		if ($topmenu) {
			$savedstreams = $topmenus;
		}
		else {
			$savedstreams = undef;
		}
		$params->{'alieniplayerrooturl'} = $url;
	} 	
	else {
		$savedstreams = $params->{'aliensavedstreams'};
	}

	if ((defined ($t->[2]->{class})) && (($t->[2]->{class} ne 'result-wrapper') && ($t->[2]->{class} ne 'schedule result-wrapper') )) {
	
		while (defined($t =  getnexttag($p,'div'))) {
			next if (!defined ($t->[2]->{class}));
			last if  (($t->[2]->{class} eq 'result-wrapper') ||($t->[2]->{class} eq 'schedule result-wrapper') ) ;
		}
	}
	
	my $schedulepage = ($t->[2]->{class} eq 'schedule result-wrapper');
#	Sholuld be a div with the result class wrapper;
	$t =  getnexttag($p,'ul');

#
# Now real work - Each row has a program.
#
	while (defined($t =  getnext2tag($p,"li","/ul"))) {
		my $h3title;
		my $playaudio = 0;
		last if ($t->[1] eq "/ul");

		$progclass = $t->[2]->{class};
		$progstack     = ($t->[2]->{class} =~ m/ stack/) ;

# Progclass is made up of a number of words which are in the display of the episode line  "episode" "stack" "most-recent" "last" "other" "unav" and "odd" 
# remove odd from class as it governs background shading.
		$progclass =~ s/ odd//;
		$progclass =~ s/ stack//;
		$progclass =~ s/ other-eps-show//;
		$progclass =~ s/ open-brand//;
		$progclass =~ s/ \d+//;
		$progtime  = '';
		if ($schedulepage ) {
			$t = getnexttag($p,"div");
			$t = getnexttag($p,"span");
			$t = getnexttag($p,"/span");
			$progtime = $t->[3];
		} 
		
		$progimg = undef;
		while (defined($t =  getnext2tag($p,'div','img'))) {

			if ($t->[1] eq 'img') {
				$progimg = defined ($t->[2]->{src}) ? $t->[2]->{src} : undef ;
				next ;
			}

			next if (!defined ($t->[2]->{class}));
			last if  ($t->[2]->{class} eq "episode-details") ;
		}
		
		last if (!defined ($t = getnexttag($p,"h3")));
		if ( defined ($t->[2]->{title})) {
			$h3title = $t->[2]->{title};
			$t = getnexttag($p,"a");
			$t = getnexttag($p,"/a");
			$progsetitle = $t->[3];
			$progsetitle =~ s/^\s*//; 
    			$progsetitle =~ s/\s*$//; 
			$progsetitle = Encode::decode_utf8( $progsetitle );
			$progsetitle = $progtime . ' ' . $progsetitle;
		} 

		last if (!defined ($t = getnexttag($p,"/h3")));
		last if (!defined ($t = getnexttag($p,"a")));
		if (defined ($t->[2]->{class})) {
			$playaudio = ($t->[2]->{class} =~ m/cta-audio/);
		}
		if (defined ($t->[2]->{href})) {
			$progurl = $t->[2]->{href};
		}

		$t = getnexttag($p,"/a");
		$progeptitle = $t->[3];
		$progeptitle =~ s/^\s*//; 
    		$progeptitle =~ s/\s*$//; 

		$t = getnexttag($p,"p");
		$t = getnexttag($p,"/p");
		$progdesc = $t->[3];
		$progdesc =~ s/^\s*//; 
    		$progdesc =~ s/\s*$//; 

		$log->debug("Progclass=\'$progclass\' progtitle=\'$progsetitle\' eptitle=\'$progeptitle\' playaudio=$playaudio");
		next unless ($playaudio || defined($schedulemenu));
		if ( ($progclass =~ m/unav/) ) {

			$log->info(" Episode unavailable $progsetitle");
			if (defined($schedulemenu)) {
				push @$savedstreams, {
					'name'   => $progsetitle . ' - ' . $progeptitle ,
					'icon'   => $progimg,
					'description' => $progdesc,
					};
			}
		}

		elsif (($progclass eq 'episode single-ep') || ($progclass eq 'episode') || ($progclass eq 'episode now-playing') || ($progclass =~ m/most-recent/) ) {
			if (defined($submenu)) {
				push @$savedstreams, {
					'name'   => $otherepstitle . ' - other episodes',
					'items'  => \@$submenu,
					'type'   => 'opml',
					'icon'   => "http://radiotime-logos.s3.amazonaws.com/a33829q.png",
					};
				$submenu = undef;
			}
			push @$savedstreams, {
				'name'   => $progsetitle . ' - ' . $progeptitle,
				'url'    => 'http://www.bbc.co.uk' . $progurl,
				'parser' => 'Plugins::Alien::Parsers::iPlayerPlayableParser',
				'type'   => 'playlist',
				'icon'   => $progimg,
				'description' => $progdesc,
				};
			$otherepstitle = $progsetitle;

		}
		elsif ($progclass eq 'episode last other-eps') {
			push @$submenu, {
				'name'   => $progsetitle . ' - ' . $progeptitle,
				'url'    => 'http://www.bbc.co.uk' . $progurl,
				'parser' => 'Plugins::Alien::Parsers::iPlayerPlayableParser',
				'type'   => 'playlist',
				'icon'   => $progimg,
				'description' => $progdesc,

				};
 			push @$savedstreams, {
				'name'   => $progsetitle . ' - other episodes',
				'items'  => \@$submenu,
				'type'   => 'opml',
				'icon'   => "http://radiotime-logos.s3.amazonaws.com/a33829q.png",
				};
			$submenu = undef;
		}
		else  {
			push @$submenu, {
				'name'   => $progsetitle . ' - ' . $progeptitle,
				'url'    => 'http://www.bbc.co.uk' . $progurl,
				'parser' => 'Plugins::Alien::Parsers::iPlayerPlayableParser',
				'type'   => 'playlist',
				'icon'   => $progimg,
				'description' => $progdesc,
				};
		}
	}

	if (($t->[1] eq "/ul") && defined($submenu)) {
		$log->info(" Some other episodes of \"$progsetitle\" are last item ");
			push @$submenu, {
				'name'   => $progsetitle . ' - ' . $progeptitle,
				'url'    => 'http://www.bbc.co.uk' . $progurl,
				'parser' => 'Plugins::Alien::Parsers::iPlayerPlayableParser',
				'type'   => 'playlist',
				'icon'   => $progimg,
				'description' => $progdesc,

				};
 			push @$savedstreams, {
				'name'   => $progsetitle . ' - other episodes',
				'items'  => \@$submenu,
				'type'   => 'opml',
				'icon'   => "http://radiotime-logos.s3.amazonaws.com/a33829q.png",
				};
			$submenu = undef;
	}

	$log->info(sprintf "found %d streams on page %d/%d of url %s", ((defined($savedstreams )) ? scalar @$savedstreams : 0 ),$currentpage,$totalpages,$url);

	if (($totalpages > 1) && ($currentpage != $totalpages)) {
		$params->{'aliensavedstreams'} = $savedstreams ;
		my $newurl =  'http://www.bbc.co.uk' . $pageurls{($currentpage+1)} ;
		$log->info("parser redirecting to $newurl");
		return {
			'type' => 'redirect',
			'url'  => $newurl
		};
		
	}

	$params->{'aliensavedstreams'} = undef ;
	$params->{'alieniplayerrooturl'} = undef;

	if ( !defined($savedstreams))  {

		$log->debug("No streams found ");

		push @$savedstreams, {
			'name'		=> "No programs found",
			'description'	=> "No programs found",
		};

		return {
			'type'  => 'opml',
			'title' => $params->{'feedTitle'},
			'items' => \@$savedstreams,
		};
	}

	# return xmlbrowser hash
	return {
		'type'  => 'opml',
#		'title' => $params->{'feedTitle'},
		'title' => $menuname,
		'items' => \@$savedstreams,
	};

}
# Local Variables:
# tab-width:4
# indent-tabs-mode:t
# End:

1;
