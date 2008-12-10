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
package Plugins::Alien::Parsers::iPlayerScheduleParser;

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

#     print "discard nexttag ". $t->[1]."\n";
  }
}


sub parse
{
    my $class  = shift;
    my $http   = shift;

    my $params = $http->params('params');
    my $url    = $params->{'url'};
    my $client = $params->{client};

    my $topmenu = defined( $params->{'item'}->{'topmenu'}); 

    my @menus;
    my $submenu;
    my $savedstreams;
    my %stations;
    my $menuname;
    my $topmenus;

    my $progclass;
    my $progid;
    my $progsummaryahref;
    my $progsummarydesc;
    my $progtitle;
    my $setitle;
    my $progurl;
    my $progdesc;

    my $progstarttime;
    my $t;
    my $currentpage;
    my $totalpages;
    my $pageofpages;
    my %pageurls;
    my $progentry;

    my $p = HTML::PullParser->new(api_version => 3, doc => ${$http->contentRef},
                                  start => 'event, tag, attr,  skipped_text',
                                  end   => 'event, tag, dtext, skipped_text',
                                  report_tags => [qw ( td tr table tbody a img span h3 div p ul li ol )]);

	while (defined($t =  getnexttag($p,'div'))) {
		next if (!defined ($t->[2]->{class}));
		last if  ($t->[2]->{class} eq "result-wrapper") ;
	}

	$t =  getnext2tag($p,'ol','table');
	if ($t->[1] eq 'ol') {
		return undef unless defined($t);
		my $searchcurrentpage = undef;
		my $searchtotalpages  = undef;	
		while (defined($t =  getnext2tag($p,"li","table"))) {
			last if ($t->[1] eq "table");

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
				$t = getnexttag($p,"table");
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

	$menuname = $t->[2]->{summary};
	$log->info ("Got table for $menuname");

#  Skip table definition
	$t = getnexttag($p,"tbody");
#
# Now real work - Each row has a program.
#
	while (defined($t =  getnext2tag($p,"tr","/tbody"))) {

		my $playaudio = 0;
		last if ($t->[1] eq "/tbody");
#	New program row
		$progclass = $t->[2]->{class};
		$progid    = $t->[2]->{id};

# Progclass is made up of a number of words which are in the display of the episode line  "episode" "most-recent" "last" "other" "unav" and "odd" 
# remove odd from class as it governs background shading.
		$progclass =~ s/ odd//;

# Loop around - columns of the table unil end of row "/tr" 
		while(defined($t = getnext2tag($p,"td","/tr"))) {
			last if ($t->[1] eq "/tr");

			if (!defined($t->[2]->{class})) {
#				2nd Column - program Title	
				last if (!defined ($t = getnexttag($p,"div")));
				last if  ($t->[2]->{class} ne "summary-and-time") ;

				last if (!defined ($t = getnexttag($p,"a")));
				last if  ($t->[2]->{class} ne "play-audio") ;
				$playaudio = 1;

				$progsummaryahref= $t->[2]->{href};
				last if (!defined ($t = getnexttag($p,"/span")));
				$progsummarydesc = $t->[3];

				last if (!defined ($t = getnexttag($p,"h3")));
				last if  ($t->[2]->{class} ne "summary") ;
				$progtitle= Encode::decode_utf8($t->[2]->{title});

				last if (!defined ($t = getnexttag($p,"a")));
				last if  ($t->[2]->{class} ne "uid url") ;
				$progurl=$t->[2]->{href};
			} 
			elsif ( $t->[2]->{class} eq "first" ) {
#				1st Column Program start time
				last if (!defined ($t = getnexttag($p,"p")));
				last if (!defined ($t = getnexttag($p,"/p")));
				$progstarttime = $t->[3];
			}
			elsif ( $t->[2]->{class} eq "last" ) {
#				3rd Column Program description !
				last if (!defined ($t = getnexttag($p,"div")));
				last if  ($t->[2]->{class} ne "details") ;

				last if (!defined ($t = getnexttag($p,"span")));
				last if (!defined ($t = getnexttag($p,"span")));
				$setitle = $t->[3];

				last if (!defined ($t = getnexttag($p,"div")));
				last if  ($t->[2]->{class} ne "description") ;

				last if (!defined ($t = getnexttag($p,"/p")));
				$progdesc = Encode::decode_utf8($t->[3]);
			} else {
				print "Unknown class " . $t->[2]->{class} ;
			}
		
		}
		$log->debug("Progclass=\'$progclass\' progtitle=\'$progtitle\' playaudio=$playaudio");
		next unless ($playaudio);
		if ( $progclass =~ m/unav/) {
			$progclass =~ s/ unav//;
			$log->info(" Episode unavailable $progtitle");
			$progentry = {
				'name'   => $progstarttime . ' ' . $progtitle,
				'description' => $progdesc,
				};

		} 
		else {
			$progentry = {
				'name'   => $progstarttime . ' ' . $progtitle,
				'url'    => 'http://www.bbc.co.uk' . $progurl,
				'parser' => 'Plugins::Alien::Parsers::iPlayerPlayableParser',
				'type'   => 'playlist',
				'description' => $progdesc,
				};

		}


		if (($progclass eq 'episode single-ep') || ($progclass =~ m/most-recent/) ) {
			push @$savedstreams, $progentry;
		}
		elsif ($progclass eq 'episode last other-eps') {
			push @$submenu, $progentry;

 			push @$savedstreams, {
				'name'   => $setitle . ' - other episodes',
				'items'  => \@$submenu,
				'type'   => 'opml',
				};
			$submenu = undef;
		}
		else  {
			push @$submenu, $progentry;
		}
	}

	$log->info(sprintf "found %d streams on page %d/%d of url %s", ((defined($savedstreams )) ? scalar @$savedstreams : 0 ),$currentpage,$totalpages,$url);

	if (($totalpages > 1) && ($currentpage != $totalpages)) {
		$params->{'aliensavedstreams'} = $savedstreams ;
	
		my $newurl =  'http://www.bbc.co.uk' . $pageurls{($currentpage+1)} ;
#		my $newurl = $params->{'alieniplayerrooturl'} . '?page=' . ($currentpage+1);
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
