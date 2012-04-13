package AssetHandler::App::CMS;

use strict;
use warnings;
use base qw( MT::Object );
use MT 4.0;
use MT::Asset;
use MT::Util qw( format_ts relative_date caturl dirify );
use File::Spec;
use AssetHandler::Util qw( is_user_can mime_type );

sub open_batch_editor {
    my $app = shift;
    my ($param) = @_;
    $param ||= {};
    my @ids = $app->param('id')
      or return "Invalid request.";
    my $type = $app->param('_type');
    my $pkg = $app->model($type)
      or return "Invalid request.";
    my $q       = $app->param;
    my $blog_id = $q->param('blog_id');
    return MT->translate( 'Invalid request.' )
        unless $blog_id;
    my $blog = $app->model('blog')->load($blog_id);
    return MT->translate( 'Invalid request.' )
        unless $blog;
    $app->validate_magic()
      or return MT->translate( 'Permission denied.' );
    my $user = $app->user;
    if (! is_user_can( $blog, $user, 'edit_assets' ) ) {
        return MT->translate( 'Permission denied.' );
    }

    my $auth_prefs = $app->user->entry_prefs;
    my $tag_delim  = chr( $auth_prefs->{tag_delim} );
    require File::Basename;
    require File::Spec;
    require JSON;
    require MT::Tag;
    my $hasher = sub {
        my ( $obj, $row ) = @_;
        my $blog = $obj->blog;
        $row->{blog_name} = $blog ? $blog->name : '-';
        $row->{class} = $obj->class;
        $row->{file_path} = $obj->file_path || '';
        $row->{url} = $obj->url;
        $row->{file_name} = File::Basename::basename( $row->{file_path} ) if $row->{file_path};
        my $meta = $obj->metadata;
        $row->{file_label} = $obj->label;
        if ( -f $row->{file_path} ) {
            my @stat = stat( $row->{file_path} );
            my $size = $stat[7];
            my ($thumb_file) =
                $obj->thumbnail_url( Height => 240, Width => 240 );
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
            $row->{image_width} = $meta->{image_width};
            $row->{image_height} = $meta->{image_height};
        }
        else {
            if ( $obj->file_name ) {
                $row->{file_is_missing} = 1;
            }
            else {
                $row->{asset_has_no_file} = 1;
                if ($obj->has_thumbnail) {
                    my ($thumb_file) = $obj->thumbnail_url( Height => 240, Width => 240 );
                    $row->{thumbnail_url} = $meta->{thumbnail_url} = $thumb_file;
                }
                $row->{asset_class} = $obj->class_label;
            }
        }
        if ( my $by = $obj->created_by ) {
            my $user = MT::Author->load($by);
            $row->{created_by} = $user ? $user->name : '';
        }
        my $created_on = $obj->created_on;
        if ($created_on) {
            $row->{created_on_formatted} =
              format_ts( MT::App::CMS::LISTING_DATE_FORMAT, $created_on, $blog, $app->user ? $app->user->preferred_language : undef );
            $row->{created_on_time_formatted} =
              format_ts( MT::App::CMS::LISTING_TIMESTAMP_FORMAT, $created_on, $blog, $app->user ? $app->user->preferred_language : undef );
            $row->{created_on_relative} = relative_date( $created_on, time, $blog );
        }
        my $modified_on = $obj->modified_on;
        if ($modified_on) {
            $row->{modified_on_formatted} =
              format_ts( MT::App::CMS::LISTING_DATE_FORMAT, $modified_on, $blog, $app->user ? $app->user->preferred_language : undef );
            $row->{modified_on_time_formatted} =
              format_ts( MT::App::CMS::LISTING_TIMESTAMP_FORMAT, $modified_on, $blog, $app->user ? $app->user->preferred_language : undef );
            $row->{modified_on_relative} = relative_date( $modified_on, time, $blog );
        }
        if (MT->version_number >= 4.25) {
            $row->{metadata_json} = JSON::to_json($meta);
        }
        else {
            $row->{metadata_json} = JSON::objToJson($meta);
        }
        my $tags = MT::Tag->join( $tag_delim, $obj->tags );
        $row->{tags} = $tags;
        $row->{asset_type} = ($obj->class || '');
    };
    my $return_args = (MT->version_number >= 5.1) ? '__mode=list&_type=asset&blog_id='
                                                  : '__mode=list_asset&blog_id=';
    return $app->listing( {
            terms => { id => \@ids, blog_id => $blog_id },
            args => { sort => 'created_on', direction => 'descend' },
            type => 'asset',
            template => 'asset_batch_editor.tmpl',
            params => {
                blog_id      => $blog_id,
                edit_blog_id => $blog_id,
                saved => $app->param('saved') || 0,
                return_args => $return_args  . $blog_id
            },
            code => $hasher
    });
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

sub cancel_assets {
    my ($app) = @_;
    my $blog = $app->blog;
    if (! $blog ) {
        return MT->translate( 'Invalid request.' );
    }
    $app->validate_magic()
     or return MT->translate( 'Permission denied.' );
    $app->call_return( );
}

sub start_transporter {
    my ($app) = @_;    
    my $plugin = MT->component('AssetHandler');
    my $blog = $app->blog;
    if (! $blog ) {
        return MT->translate( 'Invalid request.' );
    }
    my $user = $app->user;
    if (! is_user_can( $blog, $user, 'upload' ) ) {
        return MT->translate( 'Permission denied.' );
    }
    my $param;
    ($param->{path} = $blog->site_path) =~ s{/*$}{/};
    $param->{path} =~ s{\\}{/}g;
    ($param->{url}  = $blog->site_url)  =~ s{/*$}{/};
    $param->{with_entry} = ( $app->config->Asset2Entry || 0 );
    if (MT->version_number >= 5) {
        $param->{with_entry} = 1 if ( $blog->theme_id eq 'photogallery_blog');
    }
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
                $param->{make_entry} = ($q->param('make_entry') || 0);
                $param->{category_label} = ($q->param('category_label') || '');
                $param->{category_basename} = ($q->param('category_basename') || '');
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
                        full_url => $url.$file,
                        make_entry => ($q->param('make_entry') || 0),
                        category_label => ($q->param('category_label') || ''),
                        category_basename => ($q->param('category_basename') || '')
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
    my $blog = $app->blog
      or return;
    if (! $blog ) {
        return MT->translate( 'Invalid request.' );
    }
    $app->validate_magic()
      or return MT->translate( 'Permission denied.' );
    my $user = $app->user;
    if (! is_user_can( $blog, $user, 'upload' ) ) {
        return MT->translate( 'Permission denied.' );
    }
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
    (my $site_path = $blog->site_path) =~ s!\\!/!g;
    $local_file =~ s!$site_path!%r!;
    require MT::Asset;
    my $asset_pkg = MT::Asset->handler_for_file($local_basename);
    my $is_image  = defined($w)
        && defined($h)
        && $asset_pkg->isa('MT::Asset::Image');
    my $asset = $asset_pkg->load({
        'file_path' => $local_file,
        'blog_id' => $blog->id,
    }) || $asset_pkg->new;
    my $asset_is_new = 0;
    if ($asset->id) {
        $asset->modified_by( $app->user->id );
    }
    else {
        my $site_path = $blog->site_path;
        $site_path    =~ s!\\!/!g;
        my $file_path = $local_file;
        $file_path    =~ s!\\!/!g;
        $file_path    =~ s!$site_path!%r!;
        $asset = $asset_pkg->new();
        $asset->file_path($file_path);
        $asset->file_name($local_basename);
        $asset->file_ext($ext);
        $asset->blog_id($blog->id);
        $asset->created_by( $app->user->id );
        $asset_is_new = 1;
    }
    eval { require Image::ExifTool; };
    if (!$@) {
        my $exif = new Image::ExifTool;
        if (my $exif_data = $exif->ImageInfo( $asset->file_path )) {
            my $date = $exif_data->{ 'DateTimeOriginal' } || '';
            if ($date) {
                my ($year, $mon, $day, $hour, $min, $sec)
                  = ($date =~ /(\d{4}):(\d\d):(\d\d) (\d\d):(\d\d):(\d\d)/);
                my $ts = sprintf("%04d-%02d-%02d %02d:%02d:%02d", $year, $mon-1, $day, $hour, $min, $sec);
                $asset->created_on( $ts ) if $asset_is_new;
                $asset->modified_on( $ts ) if $asset_is_new;
            }
            # my $rotation = $exif_data->{Orientation} || 0;
            # my $gps = $exif_data->{GPSPosition} || '';
            # my $gpslon = $exif_data->{GPSLongitude} || '';
            # my $gpslat = $exif_data->{GPSLatitude} || '';
        }
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
    my $cb = $user->text_format || $blog->convert_paras;
    $cb = '__default__' if $cb eq '1';
    if ($asset_is_new && ($param->{make_entry} || 0)) {
        my ($entry, $category);
        my $asset_basename = (File::Basename::fileparse( $asset->file_name, qr/\.[A-Za-z0-9]+$/ ))[0];
        my $entry_title = (dirify($asset->label) || dirify($asset_basename));
        my $entry_basename = lc(dirify($asset_basename));
        if ( is_user_can( $blog, $user, 'create_post' ) ) {
            require MT::Entry;
            $entry = MT::Entry->new;
            $entry->title($entry_title);
            $entry->basename($entry_basename);
            $entry->status(MT::Entry::HOLD());
            $entry->author_id($user->id);
            $entry->text('');
            $entry->convert_breaks($cb);
            $entry->blog_id($blog->id);
            $entry->class('entry');
            $entry->save
              or die $entry->errstr;
            require MT::Category;
            my $category_label = ($param->{category_label} || '');
            my $category_basename = ($param->{category_basename} || lc($param->{category_label}) || '');
            $category = MT::Category->load({
                'label' => $category_label,
                'blog_id' => $blog->id,
            });
            if (! $category) {
                if ( is_user_can( $blog, $user, 'edit_categories' ) ) {
                    $category = MT::Category->new;
                    $category->label($category_label);
                    $category->basename($category_basename);
                    $category->blog_id($blog->id);
                    $category->class('category');
                    $category->save
                      or die $category->errstr;
                }
                else {
                    doLog( 'Create Category Permission denied.' );
                }
            }
            require MT::Placement;
            my $placement = MT::Placement->new;
            $placement->blog_id($blog->id);
            $placement->category_id($category->id);
            $placement->entry_id($entry->id);
            $placement->is_primary(1);
            $placement->save
              or die $placement->errstr;
            require MT::ObjectAsset;
            my $object = MT::ObjectAsset->new;
            $object->blog_id($blog->id);
            $object->asset_id($asset->id);
            $object->object_id($entry->id);
            $object->object_ds('entry');
            $object->save
              or die $object->errstr;
        }
        else {
            doLog( 'Create Entry Permission denied.' );
        }
    }

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

sub cb_asset_table {
    my ($cb, $app, $tmpl) = @_;
    return if (MT->version_number >= 5.1);
    my $enable = MT::ConfigMgr->instance->EnableAdditionalListing || 0;
    return unless $enable;
    if (MT->version_number < 5) {
        return if (MT->version_number < 4.25);
        my $old = <<HERE;
<th id="as-created-on"><__trans phrase="Created On"></th>
HERE
        $old = quotemeta($old);
        my $new = <<HERE;
<th id="as-created-on"><__trans phrase="Created On"></th>
<th id="as-appears-in"><__trans phrase="Appears in..."></th>
<th id="as-folder"><__trans phrase="Folder"></th>
HERE
        $$tmpl =~ s/$old/$new/;

        $old = <<HERE;
                <td class="si status-view"><mt:if name="url"><a href="<mt:var name="url">" target="view_uploaded" title="<__trans phrase="View">"><img src="<mt:var name="static_uri">images/spacer.gif" alt="<__trans phrase="View">" width="13" height="9" /></a><mt:else>&nbsp;</mt:if></td>
HERE
        $old = quotemeta($old);
        $new = <<HERE;
                <td class="si">
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
  <mt:if name="is_thumbnail">
                    <span class="is_tumbnail">-</span>
  <mt:else>
                    <span class="hint"><__trans phrase="This asset has not been used."></span>
  </mt:if>
</mt:if>
                </td>
                <td class="si"><mt:var name="folder" /></td>
                <td class="si status-view"><mt:if name="url"><a href="<mt:var name="url">" target="view_uploaded" title="<__trans phrase="View">"><img src="<mt:var name="static_uri">images/spacer.gif" alt="<__trans phrase="View">" width="13" height="9" /></a><mt:else>&nbsp;</mt:if></td>
HERE
        $$tmpl =~ s/$old/$new/;
    }
    else {
        my $old = <<HERE;
                <th class="created-on"><__trans phrase="Created On"></th>
HERE
        $old = quotemeta($old);
        my $new = <<HERE;
                <th class="created-on"><__trans phrase="Created On"></th>
                <th class="appears-in"><__trans phrase="Appears in..."></th>
                <th class="folder"><__trans phrase="Folder"></th>
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
  <mt:if name="is_thumbnail">
                    <span class="is_tumbnail">-</span>
  <mt:else>
                    <span class="hint"><__trans phrase="This asset has not been used."></span>
  </mt:if>
</mt:if>
                </td>
                <td><mt:var name="folder" /></td>
            </tr>
    <mt:if __last__>
        </tbody>
HERE
        $$tmpl =~ s/$old/$new/;
    }
}

sub cb_list_asset_pre_listing {
    my ($cb, $app, $terms, $args, $param, $hasher) = @_;
    my $enable = MT::ConfigMgr->instance->EnableAdditionalListing || 0;
    return unless $enable;
    if (MT->version_number < 5) {
        if (MT->version_number >= 4.25) {
            my $site_path = $app->blog->site_path;

            require File::Basename;
            require JSON;
            my %blogs;
            $$hasher = sub {
                my ( $obj, $row, %param ) = @_;
                my $meta = $obj->metadata;

                $row->{id} = $obj->id;
                my $blog = $blogs{ $obj->blog_id } ||= $obj->blog;
                $row->{blog_name} = $blog ? $blog->name : '-';
                $row->{url} = $obj->url;
                $row->{asset_type} = $obj->class_type;
                $row->{asset_class_label} = $obj->class_label;
                my $file_path = $obj->file_path;
                if ($file_path) {
                    $row->{file_path} = $file_path;
                    $row->{file_name} = File::Basename::basename( $file_path );

                    my $filename = File::Basename::basename( $file_path );
                    (my $tmp = $file_path) =~ s!^(.*)[/\\]$filename$!$1!;
                    $tmp =~ s!\\!/!g;
                    $site_path =~ s!\\!/!g;
                    $tmp =~ s!^$site_path(.*)$!$1!;
                    $tmp .= '/' if ($tmp);
                    $row->{folder} = $tmp;
                }
                $row->{file_label} = $row->{label} = $obj->label || $row->{file_name} || $app->translate('Untitled');

                if ($obj->has_thumbnail) { 
                    $row->{has_thumbnail} = 1;
                    my $height = 75;
                    my $width  = 75;

                    my $square = 1;
                    @$meta{qw( thumbnail_url thumbnail_width thumbnail_height )}
                        = $obj->thumbnail_url(
                          Height => $height,
                          Width  => $width,
                        );
                    $meta->{thumbnail_width_offset}
                        = int( ( $width - $meta->{thumbnail_width} ) / 2 );
                    $meta->{thumbnail_height_offset}
                        = int( ( $height - $meta->{thumbnail_height} ) / 2 );
                }
                else {
                    $row->{has_thumbnail} = 0;
                }
                $row->{is_thumbnail} = $obj->parent ? 1 : 0;
                my @appears_in;
                my $place_iter = $app->model('objectasset')->load_iter(
                    {
                        blog_id => $obj->blog_id || 0,
                        asset_id => $obj->id
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
                    $row->{appears_in_more} = 1;
                }
                $row->{appears_in} = \@appears_in if @appears_in;
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
        else {
        }
    }
    else {
        return if (MT->version_number >= 5.1);
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
                $tmp .= '/' if ($tmp);
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
            $row->{is_thumbnail} = $obj->parent ? 1 : 0;
            my @appears_in;
            my $place_class = $app->model('objectasset');
            my $place_iter = $place_class->load_iter(
                {
                    blog_id => $obj->blog_id || 0,
                    asset_id => $obj->id
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
                $row->{appears_in_more} = 1;
            }
            $row->{appears_in} = \@appears_in if @appears_in;
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
}

sub cb_list_param_asset {
    my $cb = shift;
    my ( $app, $param, $tmpl ) = @_;

    my $saved = ( $app->param('saved') || 0 );
    $param->{saved} = $saved;
    my $moved = ( $app->param('assets_moved') || 0 );
    $param->{assets_moved} = $moved;
    my $not_moved = ( $app->param('assets_not_moved') || 0 );
    $param->{assets_not_moved} = $not_moved;
}

sub cb_header_param {
    my ($cb, $app, $param, $tmpl) = @_;
    my $version = MT->version_number;
    return 1 if ($version < 5.1);
    return 1
      if ((($app->param('__mode') || '') ne 'list') || (($app->param('_type') || '') ne 'asset'));

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
      <__trans_section component="AssetHandler"><__trans phrase="The selected asset(s) has been successfully moved. Be sure to republish and double-check for any existing use of the old URL!"></__trans_section>
    </mtapp:statusmsg>
</mt:if>
<mt:if name="assets_not_moved">
    <mtapp:statusmsg
     id="assets_not_moved"
     class="success">
      <__trans_section component="AssetHandler"><__trans phrase="Some selected asset(s) has <em>not</em> been moved. The selected asset(s) are not file-based or are missing."></__trans_section>
    </mtapp:statusmsg>
</mt:if>
</mt:setvarblock>
};
    $html_head->innerHTML($innerHTML);
    $tmpl->insertBefore( $html_head, $head );
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
        next unless ($asset->file_name);
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
        if ( $asset->file_path ) {
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
        if ( $asset->file_path ) {
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
        if ( $asset->file_path ) {
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
        if ( $asset->file_path ) {
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
    (my $site_path = $blog->site_path) =~ s{\\}{/}g;
    $site_path .= '/' if ($site_path =~ m!([^/])$!);
    my $site_url = $blog->site_url;
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
        (my $dest_file = File::Spec->catfile($dest_path, $asset->file_name)) =~ s{\\}{/}g;
        $fmgr->rename($asset->file_path, $dest_file)
          or die $fmgr->errstr;
        my @object_assets = MT->model('objectasset')->load({
            'asset_id' => $asset->id,
            'blog_id' => $blog->id,
        });
        foreach my $object_asset (@object_assets) {
            if ($object_asset->object_id) {
                my $entry = MT->model('entry')->load($object_asset->object_id);
                my $text = $entry->text || '';
                my $more = $entry->text_more || '';
                my $fullpath = $asset->url;
                (my $fulldest = $dest_file) =~ s!$site_path!$site_url!;
                $text =~ s!$fullpath!$fulldest!g;
                $more =~ s!$fullpath!$fulldest!g;
                (my $relpath = $fullpath) =~ s!https?://[^/]+/!/!;
                (my $reldest = $fulldest) =~ s!https?://[^/]+/!/!;
                $text =~ s!$relpath!$reldest!g;
                $more =~ s!$relpath!$reldest!g;
                $entry->text($text);
                $entry->text_more($more);
                $entry->save
                  or die $entry->errstr;
            }
        }
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
    (my $site_path = $blog->site_path) =~ s{\\}{/}g;
    $site_path .= '/' if ($site_path =~ m!([^/])$!);
    my $site_url = $blog->site_url;
    my $q = $app->{query};
    my $filename = $q->param('itemset_action_input') || '';
    my $rename_flag;
    my @asset_ids = $q->param('id');
    foreach my $asset_id (@asset_ids) {
        my $asset = MT->model('asset')->load($asset_id)
            or next;
        next unless ( $asset->file_path );
        my $blog = MT->model('blog')->load($asset->blog_id);
        (my $basename = $filename) =~ s{\..+?$}{};
        if ( $basename eq $filename ) {
            $filename .= '.' . $asset->file_ext;
        }
        (my $folder = $asset->file_path) =~ s{\\}{/}g;
        $folder =~ s{/[^/]+$}{/};
        (my $dest_path = File::Spec->catdir($folder, $filename)) =~ s{\\}{/}g;
        my $fmgr = $blog->file_mgr;
        if ( $fmgr->exists($dest_path) ) {
            $rename_flag = 1;
        }
        else {
            $fmgr->rename($asset->file_path, $dest_path)
              or die $fmgr->errstr;
            $dest_path =~ s!$site_path!%r/!;
            my @object_assets = MT->model('objectasset')->load({
                'asset_id' => $asset->id,
                'blog_id' => $blog->id,
            });
            foreach my $object_asset (@object_assets) {
                if ($object_asset->object_id) {
                    my $entry = MT->model('entry')->load($object_asset->object_id);
                    my $text = $entry->text || '';
                    my $more = $entry->text_more || '';
                    my $fullpath = $asset->url;
                    (my $fulldest = $dest_path) =~ s!%r/!$site_url!;
                    $text =~ s!$fullpath!$fulldest!g;
                    $more =~ s!$fullpath!$fulldest!g;
                    (my $relpath = $fullpath) =~ s!https?://[^/]+/!/!;
                    (my $reldest = $fulldest) =~ s!https?://[^/]+/!/!;
                    $text =~ s!$relpath!$reldest!g;
                    $more =~ s!$relpath!$reldest!g;
                    $entry->text($text);
                    $entry->text_more($more);
                    $entry->save
                      or die $entry->errstr;
                }
            }
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
        next unless ( $asset->file_path );
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

sub doLog {
    my ($msg) = @_; 
    return unless defined($msg);
    require MT::Log;
    my $log = MT::Log->new;
    $log->message($msg) ;
    $log->save or die $log->errstr;
}

1;