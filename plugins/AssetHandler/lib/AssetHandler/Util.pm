package AssetHandler::Util;

use strict;
use warnings;

sub is_blog_context {
    my $app = MT->instance;
    my $blog_id = $app->param('blog_id');
    if ($blog_id) {
        return 1;
    }
}
sub is_mt5 {
    my $version = MT->version_id;
    if (($version < 5.1)&&($version >= 5)) {
        return 1;
    }
}
sub is_illiad {
    my $version = MT->version_id;
    if ($version >= 5.1) {
        return 1;
    }
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
