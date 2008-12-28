package Plugins::Alien::WindowsDownloader;

# Windows specifc - check for mplayer.exe and download from mplayer site if it is not available in the Bin folder

use File::Spec::Functions qw(:ALL);
use Digest::MD5;
use Archive::Zip qw(:ERROR_CODES);

use Slim::Utils::Log;
use Slim::Utils::Prefs;

my $mplayer = 'mplayer.exe';
my $zipUrl  = 'http://www.mplayerhq.hu/MPlayer/releases/win32/MPlayer-mingw32-1.0rc2.zip';
my $md5Url  = 'http://www.mplayerhq.hu/MPlayer/releases/win32/MPlayer-mingw32-1.0rc2.zip.md5';

sub checkMplayer {
	my $class  = shift;
	my $plugin = shift;

	my $bindir = catdir($plugin->pluginDir, 'Bin');

	if (! -w $bindir) {
		$plugin->mplayer('download_failed', "$bindir is not writable");
		return 0;
	}

	my $cache = preferences('server')->get('cachedir');

	my $data = {
		bindir => $bindir,
		plugin => $plugin,
		zip    => catdir($cache, 'mplayer.zip'),
		remaining => 2,
	};

	$plugin->mplayer('downloading');

	Slim::Networking::SimpleAsyncHTTP->new(\&_gotFile, \&_downloadError, { saveAs => $data->{'zip'}, data => $data } )->get($zipUrl);
	Slim::Networking::SimpleAsyncHTTP->new(\&_gotMD5,  \&_downloadError, { data => $data } )->get($md5Url);
}

sub _gotFile {
	my $http = shift;
	my $data = $http->params('data');

	if (! --$data->{'remaining'}) {
		_extract($data);
	}
}

sub _gotMD5 {
	my $http = shift;
	my $data = $http->params('data');

	($data->{'md5'}) = $http->content =~ /(\w+)\s/;

	if (! --$data->{'remaining'}) {
		_extract($data);
	}
}

sub _downloadError {
	my $http  = shift;
	my $error = shift;
	my $data = $http->params('data');

	$data->{'plugin'}->mplayer('download_failed', $http->url . " - " . $error);
}

sub _extract {
	my $data = shift;
	my $file = $data->{'zip'};
	my $plugin = $data->{'plugin'};

	my $md5 = Digest::MD5->new;

	open my $fh, '<', $file;

	binmode $fh;

	$md5->addfile($fh);

	close $fh;
		
	if ($data->{'md5'} ne $md5->hexdigest) {

		$plugin->mplayer('download_failed', 'bad md5 checksum');

	} else {

		my $zip = Archive::Zip->new();

		if ($zip->read($file) != AZ_OK) {

			$plugin->mplayer('download_failed', "error reading zip file $file");

		} elsif (my @file = $zip->membersMatching($mplayer)) {

			if ($zip->extractMember($file[0], catdir($data->{'bindir'}, $mplayer)) != AZ_OK) {
			
				$plugin->mplayer('download_failed', "error extracting $mplayer from $file");

			} if (Slim::Utils::Misc::findbin('mplayer')) {

				$plugin->mplayer('download_ok');

			} else {

				$plugin->mplayer('download_failed', 'extracted but not found by findbin');
			}

		} else {

			$plugin->mplayer('download_failed', "can't find $mplayer in $file");
		}
	}
	
	unlink $file;
}

1;
