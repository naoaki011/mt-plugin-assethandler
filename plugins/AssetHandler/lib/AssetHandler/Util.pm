package AssetHandler::Util;

use strict;
use warnings;
use Exporter;
@AssetHandler::Util::ISA = qw( Exporter );
use vars qw( @EXPORT_OK );
@EXPORT_OK = qw( is_user_can mime_type );

sub is_blog_context {
    my $app = MT->instance;
    my $blog_id = $app->param('blog_id');
    if ($blog_id) {
        return 1;
    }
}
sub is_mt5 {
    my $version = MT->version_number;
    if (($version < 5.1)&&($version >= 5)) {
        return 1;
    }
}
sub is_illiad {
    my $version = MT->version_number;
    if (($version < 5.2)&&($version >= 5.1)) {
        return 1;
    }
}
sub is_image {
    my $file = shift;
    my $basename = File::Basename::basename( $file );
    require MT::Asset;
    my $asset_pkg = MT::Asset->handler_for_file( $basename );
    if ( $asset_pkg eq 'MT::Asset::Image' ) {
        return 1;
    }
    return 0;
}

sub is_user_can {
    my ( $blog, $user, $permission ) = @_;
    $permission = 'can_' . $permission;
    my $perm = $user->is_superuser;
    unless ( $perm ) {
        if ( $blog ) {
            my $admin = 'can_administer_blog';
            $perm = $user->permissions( $blog->id )->$admin;
            $perm = $user->permissions( $blog->id )->$permission unless $perm;
        } else {
            $perm = $user->permissions()->$permission;
        }
    }
    return $perm;
}

sub mime_type {
    my $file_ext = shift;
    my %mime_type = (
        'css'   => 'text/css',
        'html'  => 'text/html',
        'mtml'  => 'text/html',
        'xhtml' => 'application/xhtml+xml',
        'htm'   => 'text/html',
        'txt'   => 'text/plain',
        'rtx'   => 'text/richtext',
        'tsv'   => 'text/tab-separated-values',
        'csv'   => 'text/csv',
        'hdml'  => 'text/x-hdml; charset=Shift_JIS',
        'xml'   => 'application/xml',
        'atom'  => 'application/atom+xml',
        'rss'   => 'application/rss+xml',
        'rdf'   => 'application/rdf+xml',
        'xsl'   => 'text/xsl',
        'mpeg'  => 'video/mpeg',
        'mpg'   => 'video/mpeg',
        'mpe'   => 'video/mpeg',
        'qt'    => 'video/quicktime',
        'avi'   => 'video/x-msvideo',
        'movie' => 'video/x-sgi-movie',
        'mov'   => 'video/quicktime',
        'ice'   => 'x-conference/x-cooltalk',
        'svr'   => 'x-world/x-svr',
        'vrml'  => 'x-world/x-vrml',
        'wrl'   => 'x-world/x-vrml',
        'vrt'   => 'x-world/x-vrt',
        'spl'   => 'application/futuresplash',
        'js'    => 'application/javascript',
        'json'  => 'application/json',
        'hqx'   => 'application/mac-binhex40',
        'doc'   => 'application/msword',
        'pdf'   => 'application/pdf',
        'ai'    => 'application/postscript',
        'eps'   => 'application/postscript',
        'ps'    => 'application/postscript',
        'rtf'   => 'application/rtf',
        'ppt'   => 'application/vnd.ms-powerpoint',
        'xls'   => 'application/vnd.ms-excel',
        'dcr'   => 'application/x-director',
        'dir'   => 'application/x-director',
        'dxr'   => 'application/x-director',
        'dvi'   => 'application/x-dvi',
        'gtar'  => 'application/x-gtar',
        'gzip'  => 'application/x-gzip',
        'latex' => 'application/x-latex',
        'lzh'   => 'application/x-lha',
        'swf'   => 'application/x-shockwave-flash',
        'sit'   => 'application/x-stuffit',
        'tar'   => 'application/x-tar',
        'tcl'   => 'application/x-tcl',
        'tex'   => 'application/x-texinfo',
        'texinfo'=>'application/x-texinfo',
        'texi'  => 'application/x-texi',
        'src'   => 'application/x-wais-source',
        'zip'   => 'application/zip',
        'au'    => 'audio/basic',
        'snd'   => 'audio/basic',
        'midi'  => 'audio/midi',
        'mid'   => 'audio/midi',
        'kar'   => 'audio/midi',
        'mpga'  => 'audio/mpeg',
        'mp2'   => 'audio/mpeg',
        'mp3'   => 'audio/mpeg',
        'ra'    => 'audio/x-pn-realaudio',
        'ram'   => 'audio/x-pn-realaudio',
        'rm'    => 'audio/x-pn-realaudio',
        'rpm'   => 'audio/x-pn-realaudio-plugin',
        'wav'   => 'audio/x-wav',
        'bmp'   => 'image/x-ms-bmp',
        'gif'   => 'image/gif',
        'jpeg'  => 'image/jpeg',
        'jpg'   => 'image/jpeg',
        'jpe'   => 'image/jpeg',
        'png'   => 'image/png',
        'tiff'  => 'image/tiff',
        'tif'   => 'image/tiff',
        'ico'   => 'image/vnd.microsoft.icon',
        'pnm'   => 'image/x-portable-anymap',
        'ras'   => 'image/x-cmu-raster',
        'pnm'   => 'image/x-portable-anymap',
        'pbm'   => 'image/x-portable-bitmap',
        'pgm'   => 'image/x-portable-graymap',
        'ppm'   => 'image/x-portable-pixmap',
        'rgb'   => 'image/x-rgb',
        'xbm'   => 'image/x-xbitmap',
        'xpm'   => 'image/x-pixmap',
        'xwd'   => 'image/x-xwindowdump',
    );
    my $type = $mime_type{ $file_ext };
    $type = 'text/plain' unless $type;
    return $type;
}

sub doLog {
    my ($msg) = @_; 
    use MT::Log; 
    my $log = MT::Log->new; 
    if ( defined( $msg ) ) { 
        $log->message( $msg ); 
    }
    $log->save or die $log->errstr; 
}

1;
