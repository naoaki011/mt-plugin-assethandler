package AssetHandler::App::CMS;

use strict;
use warnings;
use MT::Util qw( format_ts relative_date caturl );
use MT 4.0;
use MT::Asset;
use File::Spec;

sub open_batch_editor {
    my ($app) = @_;
    my $plugin     = MT->component('AssetHandler');
    my @ids = $app->param('id');
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
                return_args => "__mode=list_assets&blog_id=$blog_id"
            }
        }
    );
}

sub save_assets {
    my ($app) = @_;
    my $plugin = MT->component('AssetHandler');
    my @ids = $app->param('id');
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
    my $blog_id = $app->param('blog_id')
      or return $app->error('No blog in context for asset import');
    require MT::Blog;
    my $blog = MT::Blog->load($blog_id);
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
    my $path    = $q->param('path');
    $path       =~ s{\\}{/}g;
    my $url     = $q->param('url');
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
    my $original = $asset->clone;

    my $site_url = $blog->site_url;
    $url =~ s!\\!/!g;
    $url =~ s!$site_url!%r/!;

    $asset->url($url);
    if ($is_image) {
        $asset->image_width($w);
        $asset->image_height($h);
    }
    $asset->mime_type($mimetype) if $mimetype;
    $asset->save;
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

sub list_asset_src {
    my ( $cb, $app, $tmpl ) = @_;
    my ( $old, $new );
    # Add a saved status msg
    if ( $app->param('saved') ) {
        $old =
            q{<$mt:include name="include/header.tmpl" id="header_include"$>};
        $old = quotemeta($old);
        $new = <<HTML;
<mt:setvarblock name="content_header" append="1">
    <mtapp:statusmsg
         id="saved"
         class="success">
         <__trans phrase="Your changes have been saved.">
     </mtapp:statusmsg>
</mt:setvarblock>   
HTML
        $$tmpl =~ s/($old)/$new\n$1/;
    }
}

sub assoc_bulk_html {
    my ($prop, $assets, $app, $opts) = @_;

    # load objectassets
    my @asset_ids = map { $_->id } @$assets;
    my @obj_assets = $app->model('objectasset')->load(
        { asset_id => \@asset_ids, }
    );

    # associates with assets and objects
    my (%class_obj_ids, %asset_obj_ids, %class_objs);
    for my $obj_asset (@obj_assets) {
        my $ds = $obj_asset->object_ds;
        my $asset_id = $obj_asset->asset_id;
        my $object_id = $obj_asset->object_id;
        $asset_obj_ids{$asset_id}->{$ds} = {}
            unless (defined($asset_obj_ids{$asset_id}->{$ds}));
        $asset_obj_ids{$asset_id}->{$ds}->{$object_id} = 1;
        $class_obj_ids{$ds} = {}
            unless (defined($class_obj_ids{$ds}));
        $class_obj_ids{$ds}->{$object_id} = 1;
    }

    # load objects
    for my $class (keys %class_obj_ids) {
        my @obj_ids = keys %{$class_obj_ids{$class}};
        my @cur_class_objs = $app->model($class)->load({ id => \@obj_ids });
        my %cur_class_objs = map { $_->id => $_ } @cur_class_objs;
        $class_objs{$class} = \%cur_class_objs;
    }

    # create bulk html
    my @rows;
    for my $asset (@$assets) {
        my $html;
        my @classes = keys %{$asset_obj_ids{$asset->id}};
        for (my $i = 0; $i < scalar(@classes); $i++) {
            my $class = $classes[$i];
            $html = '<ul>' if (!$i);
            my @obj_ids = keys %{$asset_obj_ids{$asset->id}->{$class}};
            for my $obj_id (@obj_ids) {
                my $obj = $class_objs{$class}->{$obj_id};
                $html .= '<li class="assoc-' . $obj->class . '">';
                my $url = $app->uri(
                    mode => 'view',
                    args => {
                        '_type' => $obj->class,
                        'id' => $obj->id,
                        ($obj->has_column('blog_id'))
                            ? ('blog_id' => $obj->blog_id)
                            : (),
                    },
                );
                my $has_label = 0;
                for my $label_col qw( name title label ) {
                    if ($obj->has_column($label_col)) {
                       $html .= '<a href="' . $url . '" title="(' . $obj->class_label . ')' . $obj->column($label_col) . '">' . $obj->column($label_col) . '</a>';
                       $has_label = 1;
                       last;
                    }
                }
                if (!$has_label) {
                    $html .= '<a href="' . $url . '" title="(' . $obj->class_label . ')' . $obj->id . '">(' . $obj->class_label . ')ID:' . $obj->id . '</a>';
                }
                $html .= '</li>';
            }
            $html .= '</ul>' if ($i == scalar(@classes) - 1);
        }
        push @rows, ($html) ? $html : '-';
    }
    return @rows;
}

sub no_assoc_terms {
    my ( $prop, $args, $db_terms, $db_args ) = @_;
    $db_args->{joins} ||= [];
    push @{ $db_args->{joins} },
        MT->model('objectasset')->join_on(
            undef,
            {
                id => \'is null',
            },
            {
                type => 'left',
                condition => {
                    asset_id => \'= asset_id',
                },
            },
        );
    return;
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