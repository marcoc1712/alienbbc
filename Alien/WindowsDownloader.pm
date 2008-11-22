package Plugins::Alien::WindowsDownloader;

# Windows specifc - check for mplayer.exe and download from mplayer site if it is not available in the Bin folder

use File::Spec::Functions qw(:ALL);
use Digest::MD5;
use Archive::Zip qw(:ERROR_CODES);

use Slim::Utils::Log;
use Slim::Utils::Prefs;

my $log = logger('plugin.alienbbc');

my $mplayer = 'mplayer.exe';
my $zipUrl  = 'http://www.mplayerhq.hu/MPlayer/releases/win32/MPlayer-mingw32-1.0rc2.zip';
my $md5Url  = 'http://www.mplayerhq.hu/MPlayer/releases/win32/MPlayer-mingw32-1.0rc2.zip.md5';

sub checkMplayer {
	my $class  = shift;
	my $plugin = shift;

	my $bindir = catdir($plugin->_pluginDataFor('basedir'), 'Bin');

	if (-e catdir($bindir, $mplayer)) {
		$log->info("$mplayer found in $bindir");
		return 1;
	}

	if (! -w $bindir) {
		$log->warn("can't download mplayer as $bindir is not writable");
		return 0;
	}

	$log->warn("$mplayer missing - attempting to download");

	my $cache = preferences('server')->get('cachedir');

	my $data = {
		bindir => $bindir,
		zip    => catdir($cache, 'mplayer.zip'),
		remaining => 2,
	};

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

	$log->warn("unable to download " . $http->url . " - " . $error);
}

sub _extract {
	my $data = shift;
	my $file = $data->{'zip'};

	my $md5 = Digest::MD5->new;

	open my $fh, '<', $file;

	binmode $fh;

	$md5->addfile($fh);

	close $fh;
		
	if ($data->{'md5'} ne $md5->hexdigest) {

		$log->warn("downloaded file does not match m5d checksum");

	} else {

		my $zip = Archive::Zip->new();

		if ($zip->read($file) != AZ_OK) {

			$log->warn("error reading zip file $file");

		} elsif (my @file = $zip->membersMatching($mplayer)) {

			if ($zip->extractMember($file[0], catdir($data->{'bindir'}, $mplayer)) != AZ_OK) {
			
				$log->warn("error extracting $mplayer from $file");

			} else {

				$log->info("$mplayer extracted to $data->{bindir}");
			}

		} else {

			$log->warn("error extracting - can't find $mplayer in $file");
		}
	}
	
	unlink $file;
}

1;
