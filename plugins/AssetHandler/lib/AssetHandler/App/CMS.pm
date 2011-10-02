package AssetHandler::App::CMS;

use strict;
use warnings;
use base qw( MT::Object );
use MT 4.0;
use MT::Asset;
use MT::Util qw( format_ts relative_date caturl dirify );
use File::Spec;
use AssetHandler::Util qw( is_user_can mime_type );

sub open_batch_editor_listing {
    my ($app) = @_;
    my $plugin     = MT->component('AssetHandler');
    my @ids = $app->param('id');

    my $blog = $app->blog;
    if (! $blog ) {
        return MT->translate( 'Invalid request.' );
    }
    $app->validate_magic()
      or return MT->translate( 'Permission denied.' );
    my $user = $app->user;
    if (! is_user_can( $blog, $user, 'edit_assets' ) ) {
        return MT->translate( 'Permission denied.' );
    }
    my $blog_id = $blog->id;
    my $auth_prefs = $app->user->entry_prefs;
    my $tag_delim  = chr( $auth_prefs->{tag_delim} );
    require File::Basename;
    require JSON;
    # require MT::Author;
    require MT::Tag;
    my $hasher = sub {
        my ( $obj, $row ) = @_;
        my $blog = $obj->blog;
        $row->{blog_name} = $blog ? $blog->name : '-';
        $row->{file_path} = $obj->file_path; # has to be called to calculate
        $row->{url} = $obj->url; # this has to be called to calculate
        $row->{file_name} = File::Basename::basename( $row->{file_path} );
        my $meta = $obj->metadata;
        $row->{file_label} = $obj->label;
        if ( -f $row->{file_path} ) {
            my @stat = stat( $row->{file_path} );
            my $size = $stat[7];
            my ($thumb_file) =
                $obj->thumbnail_url( Height => 220, Width => 300 );
            $row->{thumbnail_url} = $meta->{thumbnail_url} = $thumb_file;
            $row->{asset_class} = $obj->class_label;
            $row->{file_size}   = $size;
            if ( $size < 1024 ) {
                $row->{file_size_formatted} = sprintf( "%d Bytes", $size );
            }
            elsif ( $size < 1024000 ) {
                $row->{file_size_formatted} =
                    sprintf( "%.1f KB", $size / 1024 );
            }
            else {
                $row->{file_size_formatted} =
                    sprintf( "%.1f MB", $size / 1024000 );
            }
        }
        else {
            $row->{file_is_missing} = 1;
        }
        my $ts = $obj->created_on;
        $row->{metadata_json} = JSON::objToJson($meta);
        my $tags = MT::Tag->join( $tag_delim, $obj->tags );
        $row->{tags} = $tags;
    };
    require File::Spec;

    return $app->listing( {
        terms => { id => \@ids, blog_id => $app->param('blog_id') },
        args => { sort => 'created_on', direction => 'descend' },
        type => 'asset',
        code => $hasher,
        template => File::Spec->catdir( $plugin->path, 'tmpl', 'asset_batch_editor.tmpl' ),
        params => { (
                $blog_id
                ? ( blog_id      => $blog_id,
                    edit_blog_id => $blog_id,
                  ) 
                : ( system_overview => 1 )
            ),
            saved => $app->param('saved') || 0,
            return_args => "__mode=list&_type=asset&blog_id=$blog_id"
        }
    });
}

sub open_batch_editor {
    my ($app) = @_;
    my $plugin     = MT->component('AssetHandler');
    my @ids = $app->param('id');

    my $blog = $app->blog;
    if (! $blog ) {
        return MT->translate( 'Invalid request.' );
    }
    $app->validate_magic()
      or return MT->translate( 'Permission denied.' );
    my $user = $app->user;
    if (! is_user_can( $blog, $user, 'upload' ) ) {
        return MT->translate( 'Permission denied.' );
    }
    my $blog_id = $app->param('blog_id');
    my $auth_prefs = $app->user->entry_prefs;
    my $tag_delim  = chr( $auth_prefs->{tag_delim} );
    require File::Basename;
    require JSON;
    # require MT::Author;
    require MT::Tag;
    my $hasher = sub {
        my ( $obj, $row ) = @_;
        my $blog = $obj->blog;
        $row->{blog_name} = $blog ? $blog->name : '-';
        $row->{file_path} = $obj->file_path; # has to be called to calculate
        $row->{url} = $obj->url; # this has to be called to calculate
        $row->{file_name} = File::Basename::basename( $row->{file_path} );
        my $meta = $obj->metadata;
        $row->{file_label} = $obj->label;
        if ( -f $row->{file_path} ) {
            my @stat = stat( $row->{file_path} );
            my $size = $stat[7];
            my ($thumb_file) =
                $obj->thumbnail_url( Height => 220, Width => 300 );
            $row->{thumbnail_url} = $meta->{thumbnail_url} = $thumb_file;
            $row->{asset_class} = $obj->class_label;
            $row->{file_size}   = $size;
            if ( $size < 1024 ) {
                $row->{file_size_formatted} = sprintf( "%d Bytes", $size );
            }
            elsif ( $size < 1024000 ) {
                $row->{file_size_formatted} =
                    sprintf( "%.1f KB", $size / 1024 );
            }
            else {
                $row->{file_size_formatted} =
                    sprintf( "%.1f MB", $size / 1024000 );
            }
        }
        else {
            $row->{file_is_missing} = 1;
        }
        my $ts = $obj->created_on;
        $row->{metadata_json} = JSON::objToJson($meta);
        my $tags = MT::Tag->join( $tag_delim, $obj->tags );
        $row->{tags} = $tags;
    };
    require File::Spec;
    return $app->listing( {
            terms => { id => \@ids, blog_id => $app->param('blog_id') },
            args => { sort => 'created_on', direction => 'descend' },
            type => 'asset',
            code => $hasher,
            template => File::Spec->catdir(
                $plugin->path, 'tmpl', 'asset_batch_editor.tmpl'
            ),
            params => { (
                    $blog_id
                    ? ( blog_id      => $blog_id,
                        edit_blog_id => $blog_id,
                      ) 
                    : ( system_overview => 1 )
                ),
                saved => $app->param('saved') || 0,
                return_args => "__mode=list&_type=asset&blog_id=$blog_id"
            }
        }
    );
}

sub save_assets {
    my ($app) = @_;
    my $plugin = MT->component('AssetHandler');
    my @ids = $app->param('id');
    my $blog = $app->blog;
    if (! $blog ) {
        return MT->translate( 'Invalid request.' );
    }
    $app->validate_magic()
     or return MT->translate( 'Permission denied.' );
    my $user = $app->user;
    if (! is_user_can( $blog, $user, 'upload' ) ) {
        return MT->translate( 'Permission denied.' );
    }

    my $blog_id = $app->param('blog_id');
    my $auth_prefs = $app->user->entry_prefs;
    my $tag_delim  = chr( $auth_prefs->{tag_delim} );
    require MT::Asset;
    require MT::Tag;
    foreach my $id (@ids) {
        my $asset = MT::Asset->load($id);
        $asset->label( $app->param("label_$id") );
        $asset->description( $app->param("description_$id") );
        if ( my $tags = $app->param("tags_$id") ) {
            my @tags = MT::Tag->split( $tag_delim, $tags );
            $asset->set_tags(@tags);
        }
        $asset->save
          or
          die $app->trans_error( "Error saving file: [_1]", $asset->errstr );
    }
    $app->call_return( saved => 1 );
}

sub start_transporter {
    my ($app) = @_;    
    my $plugin = MT->component('AssetHandler');
    my $blog = $app->blog;
    if (! $blog ) {
        return MT->translate( 'Invalid request.' );
    }
#    $app->validate_magic()
#      or return MT->translate( 'Permission denied.' );
    my $user = $app->user;
    if (! is_user_can( $blog, $user, 'upload' ) ) {
        return MT->translate( 'Permission denied.' );
    }
    my $param;
    ($param->{path} = $blog->site_path) =~ s{/*$}{/};
    $param->{path} =~ s{\\}{/}g;
    ($param->{url}  = $blog->site_url)  =~ s{/*$}{/};
    return $app->build_page( $plugin->load_tmpl('transporter.tmpl'), $param );
}

sub transport {
    my ($app) = @_;
    my $q = $app->param;
    require MT::Blog;
    my $blog_id = $app->param('blog_id')
      or return $app->error('No blog in context for asset import');
    my $blog   = MT::Blog->load($blog_id)
      or return $app->error(
        sprintf 'Failed to load blog %s: %s',
        $blog_id,
        (MT::Blog->errstr || "Blog not found")
      );

    $app->validate_magic()
      or return MT->translate( 'Permission denied.' );
    my $user = $app->user;
    if (! is_user_can( $blog, $user, 'upload' ) ) {
        return MT->translate( 'Permission denied.' );
    }
    my $path    = $q->param('path');
    $path       =~ s{\\}{/}g;
    my $url     = $q->param('url');
#    doLog($q->param('make_entry') . $q->param('asset_category'));
    my $plugin  = MT->component('AssetHandler');
    my $param   = {
        blog_id   => $blog_id,
        blog_name => $blog->name,
        path      => $path,
        url       => $app->param('url'),
        button    => 'continue',
        readonly  => 1,
    };

    if (-e $path){
        if (-f $path){
            print_transport_progress($plugin, $app, 'start');
            _process_transport($app, {
                full_path => $path,
                full_url => $url
            }); 
            $app->print($plugin->translate("Imported '[_1]'\n", $path));
            print_transport_progress($plugin, $app, 'end');
        } else {
            my @files = $q->param('file');
            # This happens on the first step
            if ( !@files ) {
                $param->{is_directory} = 1;
                my @files;
                opendir(DIR, $path) or die "Can't open $path: $!";
                while (my $file = readdir(DIR)) {
                    next if $file =~ /^\./;
                    push @files, { file => $file };
                }
                closedir(DIR);
                @files = sort { $a->{file} cmp $b->{file} } @files; 
                $param->{files} = \@files;      
            } else {
                # We get here if the user has chosen some specific files to import
                $path .= '/' unless $path =~ m!/$!; 
                $url .= '/' unless $url =~ m!/$!; 
                print_transport_progress( $plugin, $app, 'start' );
                foreach my $file (@files) {
                    next if -d $path.$file; # Skip any subdirectories for now
                    _process_transport($app, {
                        is_directory => 1,
                        path => $path,
                        url => $url,
                        file_basename => $file,
                        full_path => $path.$file,
                        full_url => $url.$file
                    });
                    $app->print($plugin->translate("Transported '[_1]'\n",
                        $path.$file));
                }
                print_transport_progress($plugin, $app, 'end'); 
            }
        }
        return $app->build_page($plugin->load_tmpl('transporter.tmpl'), $param);
    } else {
        if ($path =~ m/\/$/) {
            return $app->error($plugin->translate("Target Directory([_1]) is not found.", $path));
        } else {
            return $app->error($plugin->translate("Target File([_1]) is not found.", $path));
        }
    }
}

sub _process_transport {
    my $app = shift;
    my ($param) = @_;
    require MT::Blog;
    my $blog_id    = $app->param('blog_id');
    my $blog       = MT::Blog->load($blog_id);
    my $local_file = $param->{full_path};
    my $url        = $param->{full_url};   
    my $bytes      = -s $local_file;
    require File::Basename;
    my $local_basename = File::Basename::basename($local_file);
    my $ext = ( File::Basename::fileparse( $local_file, 
                                            qr/[A-Za-z0-9]+$/ ) )[2];
    # Copied mostly from MT::App::CMS
    my ($fh, $mimetype);
    open $fh, $local_file;
    ## Use Image::Size to check if the uploaded file is an image, and if so,
    ## record additional image info (width, height). We first rewind the
    ## filehandle $fh, then pass it in to imgsize.
    seek $fh, 0, 0;
    eval { require Image::Size; };
    return $app->error(
        $app->translate(
                "Perl module Image::Size is required to determine "
              . "width and height of uploaded images."
        )
    ) if $@;
    my ( $w, $h, $id ) = Image::Size::imgsize($fh);
    ## Close up the filehandle.
    close $fh;
    require MT::Asset;
    my $asset_pkg = MT::Asset->handler_for_file($local_basename);
    my $is_image  = defined($w)
        && defined($h)
        && $asset_pkg->isa('MT::Asset::Image');
    my $asset;
    if (
        !(
            $asset = $asset_pkg->load(
                { file_path => $local_file, blog_id => $blog_id }
            )
        )
    ) {
        my $site_path = $blog->site_path;
        $site_path    =~ s!\\!/!g;
        my $file_path = $local_file;
        $file_path    =~ s!\\!/!g;
        $file_path    =~ s!$site_path!%r!;
        $asset = $asset_pkg->new();
        $asset->file_path($file_path);
        $asset->file_name($local_basename);
        $asset->file_ext($ext);
        $asset->blog_id($blog_id);
        $asset->created_by( $app->user->id );
    } else {
        $asset->modified_by( $app->user->id );
    }

    my $site_url = $blog->site_url;
    $url =~ s!\\!/!g;
    $url =~ s!$site_url!%r/!;
    $asset->url($url);
    if ($is_image) {
        $asset->image_width($w);
        $asset->image_height($h);
    }
    require LWP::MediaTypes;
    $mimetype = LWP::MediaTypes::guess_media_type($asset->file_path);
    $asset->mime_type($mimetype) if $mimetype;
    $asset->save;

    my $original = $asset->clone;
    $app->run_callbacks( 'cms_post_save.asset', $app, $asset, $original );

    if ($is_image) {
        $app->run_callbacks(
            'cms_upload_file.' . $asset->class,
            File  => $local_file,
            file  => $local_file,
            Url   => $url,
            url   => $url,
            Size  => $bytes,
            size  => $bytes,
            Asset => $asset,
            asset => $asset,
            Type  => 'image',
            type  => 'image',
            Blog  => $blog,
            blog  => $blog
        );
        $app->run_callbacks(
            'cms_upload_image',
            File       => $local_file,
            file       => $local_file,
            Url        => $url,
            url        => $url,
            Size       => $bytes,
            size       => $bytes,
            Asset      => $asset,
            asset      => $asset,
            Height     => $h,
            height     => $h,
            Width      => $w,
            width      => $w,
            Type       => 'image',
            type       => 'image',
            ImageType  => $id,
            image_type => $id,
            Blog       => $blog,
            blog       => $blog
        );
    }
    else {
        $app->run_callbacks(
            'cms_upload_file.' . $asset->class,
            File  => $local_file,
            file  => $local_file,
            Url   => $url,
            url   => $url,
            Size  => $bytes,
            size  => $bytes,
            Asset => $asset,
            asset => $asset,
            Type  => 'file',
            type  => 'file',
            Blog  => $blog,
            blog  => $blog
        );
    }

}

sub print_transport_progress {
    my $plugin = shift;
    my ( $app, $direction ) = @_;
    $direction ||= 'start';
    if ( $direction eq 'start' ) {
        $app->{no_print_body} = 1;
        local $| = 1;
        my $charset = MT::ConfigMgr->instance->PublishCharset;
        $app->send_http_header(
            'text/html' . ( $charset ? "; charset=$charset" : '' ) );
        $app->print(
            $app->build_page( $plugin->load_tmpl('transporter_start.tmpl') )
        );
    }
    else {
        $app->print(
            $app->build_page( $plugin->load_tmpl('transporter_end.tmpl') ) );
    }
}

sub header_add_styles {
    my ($cb, $app, $param, $tmpl) = @_;
    return 1 if (($app->param('__mode') ne 'list') || ($app->param('_type') ne 'asset'));
    my $heads = $tmpl->getElementsByTagName('setvarblock');
    my $head;
    foreach (@$heads) {
        if ( $_->attributes->{name} =~ /html_head$/ ) {
            $head = $_;
            last;
        }
    }
    return 1 unless $head;
    require MT::Template;
    bless $head, 'MT::Template::Node';
    my $html_head = $tmpl->createElement( 'setvarblock',
        { name => 'html_head', append => 1 } );
    my $innerHTML = q{
<style type="text/css">
#asset-table th.parent {
    display: table-cell;
    width: 8em;
}
#asset-table th.class {
    width: 8em;
}
#asset-table th.file_name {
    width: 20em;
}
#asset-table th.tags {
    width: 12em;
}
#asset-table td.parent {
    display: block;
    width: auto;
}
</style>
};
    $html_head->innerHTML($innerHTML);
    $tmpl->insertBefore( $html_head, $head );
    1;
}

sub messaging_param {
    my ($cb, $app, $param, $tmpl) = @_;
    my $q = $app->query;

    $param->{assets_moved} = $q->param('assets_moved') || '';
    $param->{assets_not_moved} = $q->param('assets_not_moved') || '';
}

sub list_asset_src {
    my ( $cb, $app, $tmpl ) = @_;
    my ( $old, $new );
    # Add a saved status msg
    $old =
        q{<$mt:include name="include/header.tmpl" id="header_include"$>};
    $old = quotemeta($old);
    $new = <<HTML;
<mt:setvarblock name="content_header" append="1">
    <mt:if name="saved">
        <mtapp:statusmsg
            id="saved"
            class="success">
            <__trans phrase="Your changes have been saved.">
        </mtapp:statusmsg>
    </mt:if>
    <mt:if name="assets_moved">
        <mtapp:statusmsg
            id="assets_moved"
            class="success">
            The selected asset(s) have been successfully moved. Be sure to republish and double-check for any existing use of the old URL!
        </mtapp:statusmsg>
    </mt:if>
    <mt:if name="assets_not_moved">
        <mtapp:statusmsg
            id="assets_not_moved"
            class="success">
            The selected asset(s) have <em>not</em> been successfully moved. The selected asset(s) are not file-based or are missing.
        </mtapp:statusmsg>
    </mt:if>
</mt:setvarblock>
HTML
    $$tmpl =~ s/($old)/$new\n$1/;
}

sub list_asset {
    my ($cb, $app, $terms, $args, $param, $hasher) = @_;

    my $default_thumb_width = 75;
    my $default_thumb_height = 75;
    my $default_preview_width = 75;
    my $default_preview_height = 75;

    my $site_path = $app->blog->site_path;

    require File::Basename;
    require JSON;
    my %blogs;
    $$hasher = sub {
        my ( $obj, $row, %param ) = @_;
        my ($thumb_width, $thumb_height) = @param{qw( ThumbWidth ThumbHeight )};
        $row->{id} = $obj->id;
        my $blog = $blogs{ $obj->blog_id } ||= $obj->blog;
        $row->{blog_name} = $blog ? $blog->name : '-';
        $row->{url} = $obj->url; # this has to be called to calculate
        $row->{asset_type} = $obj->class_type;
        $row->{asset_class_label} = $obj->class_label;
        my $file_path = $obj->file_path; # has to be called to calculate
        my $meta = $obj->metadata;
        require MT::FileMgr;
        my $fmgr = MT::FileMgr->new('Local');
        ## TBD: Make sure $file_path is file, not directory.
        if ( $file_path && $fmgr->exists( $file_path ) ) {
            $row->{file_path} = $file_path;
            $row->{file_name} = File::Basename::basename( $file_path );

            my $filename = File::Basename::basename( $file_path );
            (my $tmp = $file_path) =~ s!^(.*)[/\\]$filename$!$1!;
            $tmp =~ s!\\!/!g;
            $site_path =~ s!\\!/!g;
            $tmp =~ s!^$site_path(.*)$!$1!;
            $row->{folder} = $tmp;

            my $size = $fmgr->file_size( $file_path );
            $row->{file_size} = $size;
            if ( $size < 1024 ) {
                $row->{file_size_formatted} = sprintf( "%d Bytes", $size );
            }
            elsif ( $size < 1024000 ) {
                $row->{file_size_formatted} =
                  sprintf( "%.1f KB", $size / 1024 );
            }
            else {
                $row->{file_size_formatted} =
                  sprintf( "%.1f MB", $size / 1024000 );
            }
            $meta->{'file_size'} = $row->{file_size_formatted};
        }
        else {
            $row->{file_is_missing} = 1 if $file_path;
        }
        $row->{file_label} = $row->{label} = $obj->label || $row->{file_name} || $app->translate('Untitled');

        if ($obj->has_thumbnail) { 
            $row->{has_thumbnail} = 1;
            my $height = $thumb_height || $default_thumb_height || 75;
            my $width  = $thumb_width  || $default_thumb_width  || 75;
            my $square = $height == 75 && $width == 75;
            @$meta{qw( thumbnail_url thumbnail_width thumbnail_height )}
              = $obj->thumbnail_url( Height => $height, Width => $width , Square => $square );

            $meta->{thumbnail_width_offset}  = int(($width  - $meta->{thumbnail_width})  / 2);
            $meta->{thumbnail_height_offset} = int(($height - $meta->{thumbnail_height}) / 2);

            if ($default_preview_width && $default_preview_height) {
                @$meta{qw( preview_url preview_width preview_height )}
                  = $obj->thumbnail_url(
                    Height => $default_preview_height,
                    Width  => $default_preview_width,
                );
                $meta->{preview_width_offset}  = int(($default_preview_width  - $meta->{preview_width})  / 2);
                $meta->{preview_height_offset} = int(($default_preview_height - $meta->{preview_height}) / 2);
            }
        }
        else {
            $row->{has_thumbnail} = 0;
        }

### New >
        my @appears_in;
        my $place_class = $app->model('objectasset');
        my $place_iter = $place_class->load_iter(
            {
                blog_id => $obj->blog_id || 0,
                asset_id => $obj->parent ? $obj->parent : $obj->id
            }
        );
        while (my $place = $place_iter->()) {
            my $entry_class = $app->model($place->object_ds) or next;
            next unless $entry_class->isa('MT::Entry');
            my $entry = $entry_class->load($place->object_id)
                or next;
            my %entry_data = (
                id    => $place->object_id,
                class => $entry->class_type,
                entry => $entry,
                title => $entry->title,
            );
            if (my $ts = $entry->authored_on) {
                $entry_data{authored_on_ts} = $ts;
                $entry_data{authored_on_formatted} =
                  format_ts( MT::App::CMS::LISTING_DATETIME_FORMAT(), $ts, undef,
                    $app->user ? $app->user->preferred_language : undef );
            }
            if (my $ts = $entry->created_on) {
                $entry_data{created_on_ts} = $ts;
                $entry_data{created_on_formatted} =
                  format_ts( MT::App::CMS::LISTING_DATETIME_FORMAT(), $ts, undef,
                    $app->user ? $app->user->preferred_language : undef );
            }
            push @appears_in, \%entry_data;
        }
        if (4 == @appears_in) {    
            pop @appears_in;
            $param->{appears_in_more} = 1;
        }
        $param->{appears_in} = \@appears_in if @appears_in;
### New <

        my $ts = $obj->created_on;
        if ( my $by = $obj->created_by ) {
            my $user = MT::Author->load($by);
            $row->{created_by} = $user ? $user->name : $app->translate('(user deleted)');
        }
        if ($ts) {
            $row->{created_on_formatted} =
              format_ts( MT::App::CMS::LISTING_DATE_FORMAT(), $ts, $blog, $app->user ? $app->user->preferred_language : undef );
            $row->{created_on_time_formatted} =
              format_ts( MT::App::CMS::LISTING_TIMESTAMP_FORMAT(), $ts, $blog, $app->user ? $app->user->preferred_language : undef );
            $row->{created_on_relative} = relative_date( $ts, time, $blog );
        }

        @$row{keys %$meta} = values %$meta;
        $row->{metadata_json} = MT::Util::to_json($meta);
        $row;
    };
}

sub asset_table {
    my ($cb, $app, $tmpl) = @_;

    my $old = <<HERE;
                <th class="created-on"><__trans phrase="Created On"></th>
            </tr>
        </mt:setvarblock>
HERE
    $old = quotemeta($old);

    my $new = <<HERE;
                <th class="created-on"><__trans phrase="Created On"></th>
                <th class="created-on"><__trans phrase="Appears in..."></th>
                <th class="created-on"><__trans phrase="Folder"></th>
            </tr>
        </mt:setvarblock>
HERE

    $$tmpl =~ s/$old/$new/;

    $old = <<HERE;
            </tr>
    <mt:if __last__>
        </tbody>
HERE
    $old = quotemeta($old);

    $new = <<HERE;
                <td>
    <mt:if name="appears_in">
        <mt:loop name="appears_in">
        <mt:if name="__first__">
        <ul>
        </mt:if>
            <li><a href="<mt:var name="script_url">?__mode=edit&amp;_type=<mt:var name="class">&amp;blog_id=<mt:var name="blog_id" escape="url">&amp;id=<mt:var name="id" escape="url">" class="icon-left icon-<mt:var name="class" lower_case="1">"><mt:var name="title" escape="html" default="..."></a></li>
        <mt:if name="__last__">
        </ul>
        </mt:if>
        </mt:loop>
        <mt:if name="appears_in_more">
        <p><a href="<mt:var name="script_url">?__mode=list_entry&amp;blog_id=<mt:var name="blog_id" escape="url">&amp;filter=asset_id&amp;filter_val=<mt:var name="id" escape="url">"><__trans phrase="Show all entries"></a></p>
        <p><a href="<mt:var name="script_url">?__mode=list_page&amp;blog_id=<mt:var name="blog_id" escape="url">&amp;filter=asset_id&amp;filter_val=<mt:var name="id" escape="url">"><__trans phrase="Show all pages"></a></p>
        </mt:if>
    <mt:else>
        <span class="hint"><__trans phrase="This asset has not been used."></span>
    </mt:if>
                </td>
                <td><mt:var name="folder" /></td>
            </tr>
    <mt:if __last__>
        </tbody>
HERE

    $$tmpl =~ s/$old/$new/;
}

sub unlink_asset {
    my ($app) = @_;
    my $blog = $app->blog;
    if (! $blog ) {
        return MT->translate( 'Invalid request.' );
    }
    $app->validate_magic()
      or return MT->translate( 'Permission denied.' );
    my $user = $app->user;
    if (! is_user_can( $blog, $user, 'upload' ) ) {
        return MT->translate( 'Permission denied.' );
    }
    my @ids = $app->param('id');
    require MT::Asset;
    foreach my $id (@ids) {
        my $asset = MT::Asset->load($id);
#        $asset->remove_cached_files;
        # remove children.
#        my $class = ref $asset;
#        my $iter = __PACKAGE__->load_iter({ parent => $asset->id, class => '*' });
#        while(my $a = $iter->()) {
#            $a->SUPER::remove;
#        }
        # Remove MT::ObjectAsset records
        my $class = MT->model('objectasset');
        my $iter = $class->load_iter({ asset_id => $asset->id });
        while (my $o = $iter->()) {
            $o->remove;
        }
        $asset->SUPER::remove;
    }
    $app->call_return( deleted => 1 );
}

sub path_tor {
    my ($app) = @_;
    my $blog = $app->blog;
    if (! $blog ) {
        return MT->translate( 'Invalid request.' );
    }
    $app->validate_magic()
      or return MT->translate( 'Permission denied.' );
    my $user = $app->user;
    if (! is_user_can( $blog, $user, 'edit_assets' ) ) {
        return MT->translate( 'Permission denied.' );
    }
    (my $site_path = $blog->site_path) =~ s!\\!/!g;
    my $site_url = $blog->site_url;
    my @ids = $app->param('id');
    require MT::Asset;
    foreach my $id (@ids) {
        my $asset = MT::Asset->load($id);
        if ( $asset->class =~ /image|audio|video|file|archive/) {
            (my $file_path = $asset->file_path) =~ s!\\!/!g;
            $file_path =~ s!$site_path!%r!;
            $asset->file_path( $file_path );
            (my $file_url = $asset->url) =~ s!\\!/!g;
            $file_url =~ s!$site_url!%r/!;
            $asset->url( $file_url );
            $asset->save
              or die $asset->errstr;
        }
    }
    $app->call_return( modified => 1 );
}

sub flatten_path {
    my ($app) = @_;
    my $blog = $app->blog;
    if (! $blog ) {
        return MT->translate( 'Invalid request.' );
    }
    $app->validate_magic()
      or return MT->translate( 'Permission denied.' );
    my $user = $app->user;
    if (! is_user_can( $blog, $user, 'edit_assets' ) ) {
        return MT->translate( 'Permission denied.' );
    }
    (my $site_path = $blog->site_path) =~ s!\\!/!g;
    my $site_url = $blog->site_url;
    my @ids = $app->param('id');
    require MT::Asset;
    foreach my $id (@ids) {
        my $asset = MT::Asset->load($id);
        if ( $asset->class =~ /image|audio|video|file|archive/) {
            (my $file_path = $asset->file_path) =~ s!\\!/!g;
            $file_path =~ s!%r!$site_path!;
            $asset->file_path( $file_path );
            (my $file_url = $asset->url) =~ s!\\!/!g;
            $file_url =~ s!%r/!$site_url!;
            $asset->url( $file_url );
            $asset->save
              or die $asset->errstr;
        }
    }
    $app->call_return( modified => 1 );
}

sub fix_url {
    my ($app) = @_;
    my $blog = $app->blog;
    if (! $blog ) {
        return MT->translate( 'Invalid request.' );
    }
    $app->validate_magic()
      or return MT->translate( 'Permission denied.' );
    my $user = $app->user;
    if (! is_user_can( $blog, $user, 'edit_assets' ) ) {
        return MT->translate( 'Permission denied.' );
    }
    (my $site_path = $blog->site_path) =~ s!\\!/!g;
    my @ids = $app->param('id');
    require MT::Asset;
    foreach my $id (@ids) {
        my $asset = MT::Asset->load($id);
        if ( $asset->class =~ /image|audio|video|file|archive/) {
            (my $file_path = $asset->file_path) =~ s!\\!/!g;
            $file_path =~ s!$site_path!!;
            my $url = '%r' . $file_path;
            $url =~ s!//!/!;
            $asset->url( $url );
            $asset->save
              or die $asset->errstr;
        }
    }
    $app->call_return( modified => 1 );
}

sub modify_path {
    my ($app) = @_;
    my $blog = $app->blog;
    if (! $blog ) {
        return MT->translate( 'Invalid request.' );
    }
    $app->validate_magic()
      or return MT->translate( 'Permission denied.' );
    my $user = $app->user;
    if (! is_user_can( $blog, $user, 'edit_assets' ) ) {
        return MT->translate( 'Permission denied.' );
    }

    my $q = $app->{query};
    my @aids = $q->param ('id');
    my $folder = $q->param('itemset_action_input') || '';

    foreach (@aids) {
        my $asset = MT::Asset->load ({ id => $_ })
            or next;
        if ( $asset->class =~ /image|audio|video|file|archive/) {
            (my $local_path = File::Spec->catfile('%r', $folder, $asset->file_name)) =~ s!\\!/!g;
            $asset->file_path($local_path);
            $asset->url($local_path);
            $asset->save
              or die $asset->errstr;
        }
    }

    $app->call_return( modified => 1 );
}

sub move_assets {
    my ($app) = @_;
    my $blog = $app->blog;
    if (! $blog ) {
        return MT->translate( 'Invalid request.' );
    }
    $app->validate_magic()
      or return MT->translate( 'Permission denied.' );
    my $user = $app->user;
    if (! is_user_can( $blog, $user, 'edit_assets' ) ) {
        return MT->translate( 'Permission denied.' );
    }
    my $q = $app->{query};
    my $folder = $q->param('itemset_action_input') || '';
    my @folders = split('/', $folder);
    map { $_ = dirify($_) } @folders;
    my $moved_flag;
    my @asset_ids = $q->param('id');
    foreach my $asset_id (@asset_ids) {
        my $asset = MT->model('asset')->load($asset_id)
            or next;
        next unless $asset->file_path && -e $asset->file_path;
        my $blog = MT->model('blog')->load($asset->blog_id);
        my $fmgr = $blog->file_mgr;
        my $dest_path = File::Spec->catdir($blog->site_path, @folders);
        if ( !$fmgr->exists($dest_path) ) {
            $fmgr->mkpath($dest_path)
                or die $fmgr->errstr;
        }
        my $dest_file = File::Spec->catfile($dest_path, $asset->file_name);
        $fmgr->rename($asset->file_path, $dest_file)
            or die $fmgr->errstr;
        $asset->file_path(
            File::Spec->catfile('%r', @folders, $asset->file_name)
        );
        $asset->url(
            join('/', '%r', @folders) . '/' . $asset->file_name
        );
        $asset->save
          or die $asset->errstr;
        $moved_flag = 1;
    }
    $moved_flag 
        ? $app->add_return_arg( assets_moved => 1 )
        : $app->add_return_arg( assets_not_moved => 1 );
    $app->call_return;
}

sub rename_assets {
    my ($app) = @_;
    my $blog = $app->blog;
    if (! $blog ) {
        return MT->translate( 'Invalid request.' );
    }
    $app->validate_magic()
      or return MT->translate( 'Permission denied.' );
    my $user = $app->user;
    if (! is_user_can( $blog, $user, 'edit_assets' ) ) {
        return MT->translate( 'Permission denied.' );
    }
    my $q = $app->{query};
    my $filename = $q->param('itemset_action_input') || '';
    my $rename_flag;
    my @asset_ids = $q->param('id');
    foreach my $asset_id (@asset_ids) {
        my $asset = MT->model('asset')->load($asset_id)
            or next;
        my $blog = MT->model('blog')->load($asset->blog_id);
        (my $basename = $filename) =~ s{\..+?$}{};
        if ( $basename eq $filename ) {
            $filename .= '.' . $asset->file_ext;
        }
        (my $folder = $asset->file_path) =~ s{\\}{/}g;
        $folder =~ s{/[^/]+$}{/};
        my $dest_path = File::Spec->catdir($folder, $filename);
        my $fmgr = $blog->file_mgr;
        if ( $fmgr->exists($dest_path) ) {
            $rename_flag = 1;
        }
        else {
            $fmgr->rename($asset->file_path, $dest_path)
              or die $fmgr->errstr;
            $dest_path =~ s{\\}{/}g;
            (my $site_path = $blog->site_path) =~ s{\\}{/}g;
            $dest_path =~ s!$site_path!%r!;
            $asset->file_path( $dest_path );
            $asset->url( $dest_path );
            $asset->file_name( $filename );
            $asset->save
              or die $asset->errstr;
        }
    }
    $rename_flag 
        ? $app->add_return_arg( assets_renamed => 1 )
        : $app->add_return_arg( error => 1 );
    $app->call_return;
}

sub fix_datas {
    my ($app) = @_;
    my $blog = $app->blog;
    if (! $blog ) {
        return MT->translate( 'Invalid request.' );
    }
    $app->validate_magic()
      or return MT->translate( 'Permission denied.' );
    my $user = $app->user;
    if (! is_user_can( $blog, $user, 'edit_assets' ) ) {
        return MT->translate( 'Permission denied.' );
    }

    my $q = $app->{query};
    my @aids = $q->param ('id');
    my $site_url = $blog->site_url;

    foreach (@aids) {
        my $asset = MT::Asset->load ({ id => $_ })
            or next;
        (my $file_path = $asset->url) =~ s!$site_url!%r/!;
        $file_path =~ s!\\!/!;
        $file_path =~ s!//!/!;
        $asset->url($file_path);
        $asset->file_path($file_path);
        $asset->mime_type( mime_type($asset->file_ext) );
        if ($asset->file_name eq $asset->label) {
            (my $file_name = $asset->url) =~ s{^.*/}{};
            $asset->file_name($file_name);
            $asset->label($file_name);
        }
        else {
            (my $file_name = $asset->url) =~ s{^.*/}{};
            $asset->file_name($file_name);
        }
        $asset->save
          or die $asset->errstr;
    }

    $app->call_return( modified => 1 );
}

sub find_duplicated {
    my ($app) = @_;



}

sub doLog {
    my ($msg) = @_; 
    return unless defined($msg);
    require MT::Log;
    my $log = MT::Log->new;
    $log->message($msg) ;
    $log->save or die $log->errstr;
}

1;