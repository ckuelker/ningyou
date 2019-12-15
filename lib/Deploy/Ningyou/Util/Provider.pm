# +---------------------------------------------------------------------------+
# | Deploy::Ningyou::Util::Provider                                           |
# |                                                                           |
# | Utilities for Provider                                                    |
# |                                                                           |
# | Version: 0.1.0 (change our $version inside)                               |
# |                                                                           |
# | Changes:                                                                  |
# |                                                                           |
# | 0.1.0 2019-04-26 Christian Kuelker <c@c8i.org>                            |
# |     - initial release                                                     |
# |                                                                           |
# +---------------------------------------------------------------------------+
package Deploy::Ningyou::Util::Provider;

# ABSTRACT: Utilities for Provider

use warnings;
use strict;
use Moose::Role;
use File::Basename qw(basename dirname);
use Data::Dumper;

requires qw(
    register
    parameter
    parameter_default
    parameter_description
    attribute
    attribute_default
    attribute_description
    set_dst
    set_cmd
);
with qw(Deploy::Ningyou::Util);

our $version = '0.1.0';

# IN:
#   cfg:
#   loc:
#   sec:
#   opt
#   dry
# OUT
#   1: global return value                  0|1
#   2: command queue (stack)                [ { cmd=>,verbose=>},.. ]
#   3: output stack                         []
#   4: error stack                          []
#   5: result stack                         []
sub standard_apply {
    my ( $s, $i ) = @_;
    $i = $s->validate_parameter( $s->parameter, $i, $s->parameter_default );
    my $verbose = $s->get_verbose($i);
    my $cmd     = $s->get_cmd;
    if ( $i->{dry} ) {
        return ( 1, $cmd, [], [], [] );
    }
    else {
        return $s->execute_stack( { cmd => $cmd, verbose => $verbose } );
    }
    return ( 0, [], [], [], [] );
}

# IN:
#     i : input from applied
# REMARKS:
#     pm: mandatory parameter from provider
#     pd: default values for parameters from provider
#     am: mandatory section configuration attributes
#     ad: default values for attributes from section configuration
# --- [ applied helpers ] -----------------------------------------------------
sub applied_in {
    my ( $s, $i ) = @_;
    $i = $s->validate_parameter( { i => 1 }, $i, {} );

    my $wt = $s->get_worktree;
    my $pm = $s->parameter;
    my $pd = $s->parameter_default;
    my $am = $s->attribute;
    my $ad = $s->attribute_default;

    # validate Povider::*'s applied parameter
    $i->{i} = $s->validate_parameter( $pm, $i->{i}, $pd );
    my $v = $s->get_verbose( $i->{i} );
    my ( $sec, $cls, $prv, $dst ) = $s->validated_section( $i->{i}->{sec} );
    $s->set_dst($dst);
    my $cfg = { %{ $i->{i}->{cfg} } };    # shallow copy is enough
    my $loc = $i->{i}->{loc};
    my $dat = { cfg => $cfg, attr => $am, sec => $sec, loc => $loc, };
    my $ok = $s->is_section_ok( { sec_dat => $dat } );

    # set default values to attributes of section configuration
    my $c = {};
    foreach my $k ( sort keys %{$am} ) {    # source, version, ensure ...
        $c->{$k}
            = ( exists $cfg->{$k} and defined $cfg->{$k} and $cfg->{$k} )
            ? $cfg->{$k}
            : exists $ad->{$k} ? $ad->{$k}
            :                    0;
        if ( $k eq 'source' ) {
            $c->{$k} = $s->url( $wt, $c->{$k} );
        }
        elsif ( $k eq 'mode' ) {
            $c->{$k} = $s->pad_file_mode_with_zero( $c->{$k} );
        }
    }

    # print a header, if verbose
    my $opt = { %{$c} };    # shallow copy is enough
    $opt->{section} = $s->c( 'section', $sec );
    my @cmd = $s->prv_info($opt);
    $s->set_cmd( \@cmd );
    return ( $v, $sec, $cls, $prv, $dst, $cfg, $c, $loc, $ok );
}

# --- [ section ] -------------------------------------------------------------
# IN:
#     sec_dat : {}
# OUT:
#     1|0
# -----------------------------------------------------------------------------
# 'sec_dat' => {
#    'cfg' => {
#        'destination' => 'Dist::Zilla::Plugin::PerlTidy',
#        'require' => 'global:package:libpath-iterator-rule-perl',
#        'ensure' => 'latest'
#       },
#    'attr' => {
#        'require' => 0,
#        'destination' => 1,
#        'source' => 0,
#        'mode' => 0,
#        'owner' => 0,
#        'ensure' => 0,
#        'group' => 0,
#        'checksum' => 0,
#        'comment' => 0
#       },
#    'loc' => '/srv/ningyou/global/modules/global:devel/manifests/global:devel.ini',
#    'sec' => 'global:cpan:Dist::Zilla::Plugin::PerlTidy'
#     }
# };
sub is_section_ok {
    my ( $s, $i ) = @_;
    $i = $s->validate_parameter( { sec_dat => 1, }, $i, {} );
    my $c
        = $s->validate_parameter(
        { cfg => 1, attr => 1, sec => 1, loc => 1, },
        $i->{sec_dat}, {} );
    my @cfg  = sort keys %{ $c->{cfg} };
    my @attr = sort keys %{ $c->{attr} };
    my $lc
        = List::Compare->new( { lists => [ \@cfg, \@attr ], unsorted => 1 } );
    my @cfg_only = $lc->get_unique;
    my $r        = 1;

    # check for mandatory attributes
    my $sec_c = $s->c( 'section', $c->{sec} );
    my $loc_c = $s->c( 'file',    $c->{loc} );
    foreach my $a (@attr) {
        my $str = "attribute [$a]" . " in section [$sec_c]" . " at [$loc_c]";
        if ( $c->{attr}->{$a} and not exists $c->{cfg}->{$a} ) {
            $s->e( "No $str", 'attribute' );
        }
        else {
            $s->d($str);
        }
    }

    # check for unknown attributes
    if ( scalar @cfg_only > 0 ) {
        $r = 0;    # section not OK
        my $co = scalar @cfg_only;
        my $unknown = join qq{, }, @cfg_only;
        my $str
            = "Found $co unknown attribute(s): "
            . $s->c( 'error', $unknown )
            . "\nin ["
            . $s->c( 'module', $c->{sec} )
            . "]\nat ["
            . $s->c( 'file', $c->{loc} ) . "]";
        $s->e( $str . Dumper($i), 'cfg' ) if scalar @cfg_only > 0;
    }
    return $r;
}

# IN
#     sec : section
# OUT
#     sec: global:cpan:Dist::Zilla::Plugin::PerlTidy,
#     cls: global,
#     prv: cpan,
#     dsy: Dist::Zilla::Plugin::PerlTidy

sub validated_section {
    my ( $s, $sec0 ) = @_;
    my ( $c, $p, $d ) = $s->parse_section($sec0);
    my $sec1 = $s->assemble_section( { cls => $c, prv => $p, dst => $d } );
    $s->e( 'no class', 'cfg' ) if $c eq q{};
    return ( $sec1, $c, $p, $d );
}

# IN
#     cls : class
#     prv : provider
#     dst : destination
# OUT
#     sct : section
sub assemble_section {
    my ( $s, $i ) = @_;
    $i = $s->validate_parameter( { cls => 1, prv => 1, dst => 1 }, $i, {} );
    return "$i->{cls}:$i->{prv}:$i->{dst}";
}

sub prv_info {
    my ( $s, $i ) = @_;
    my $sec
        = exists $i->{section}
        ? $i->{section}
        : $s->e( 'no [section]', 'sp' );

    my $sec_c = $s->c( 'section', $sec );
    my $d     = q{-};
    my $str   = substr $d x 3 . " [ $sec ] " . $d x 77, 0, 87;

    my @cmd = ();
    push @cmd, { verbose => $str };
    my $ml = 0;
    foreach my $k ( sort keys %{$i} ) {
        next if $k eq 'section';
        $ml = ( ( length $k ) > $ml ) ? length $k : $ml;
    }
    foreach my $k ( sort keys %{$i} ) {
        next if $k eq 'section';
        my $fmt = "  %-${ml}s: %s";
        my $c
            = $s->exists_color($k)
            ? $s->c( $k, $i->{$k} )
            : $i->{$k};
        push @cmd, { verbose => sprintf $fmt, $k, $c, };
    }
    return @cmd;
}

# --- [ url ] -----------------------------------------------------------------
# calculate Ningyou URL
# ningyou://
sub url {
    my ( $s, $wt, $url ) = @_;
    $s->d("input url [$url]");
    return $url if $url =~m{http}gmx;
    $url =~ s{ningyou://}{$wt/}gmx;
    $s->d("fully qualified file nane [$url]");
    $url =~ s{//}{/}gmx;
    return $url;
}

# --- [ file helpers ] --------------------------------------------------------
sub get_owner_of_file {
    my ( $s, $fn ) = @_;
    return undef if not -e $fn;
    my $uid = ( stat $fn )[4];
    $s->e( "can not stat file owner of [$fn]", 'permission' )
        if not defined $uid;
    my $ow0 = ( getpwuid $uid )[0];
    return $ow0;
}

# IN:
#     filename: STR
#     owner:    STR      # REM: expected owner
# OUT:
#     1|0
#sub is_owner_the_same {
#    my ( $s, $i ) = @_;
#    $i = $s->validate_parameter( { fn => 1, name => 1 }, $i, {} );
#    my $got_owner = $s->get_owner_of_file( $i->{fn} );
#    return 1 if $got_owner eq $i->{expected_owner};
#    return 0;
#}

sub get_group_of_file {
    my ( $s, $fn ) = @_;
    return undef if not -e $fn;
    my $gid = ( stat $fn )[5];
    $s->e( "can not stat file group of [$fn]", 'permission' )
        if not defined $gid;
    my $gr0 = ( getgrgid $gid )[0];
    return $gr0;
}

sub get_mode_of_file {
    my ( $s, $fn ) = @_;
    return undef if not -e $fn;
    my $md0 = sprintf( "%04o", ( stat $fn )[2] & 07777 );
    $s->e( "can not stat file mode of [$fn]", 'permission' )
        if not defined $md0;
    chomp $md0;
    return $md0;
}

# pad file mode with zero if needed
# 640 -> 0640, 2640->2640
sub pad_file_mode_with_zero {
    my ( $s, $mode ) = @_;
    my $l = length $mode;
    $mode = '0' . $mode if $l == 3;
    return $mode;
}

# check if 2 files have same checksum
sub file_md5_eq {
    my ( $s, $cache, $fn1, $fn2 ) = @_;
    my $d1 = $s->get_md5( $cache, $fn1 );
    my $d2 = $s->get_md5( $cache, $fn2 );
    return 1 if $d1 eq $d2;
    return 0;
}

# calculate md5 checksum
sub get_md5 {
    my ( $s, $cache, $fn ) = @_;
    my $digest = q{};
    if ( exists $cache->{$fn} ) {
        $digest = $cache->{$fn};
    }
    else {
        my $ctx = Digest::MD5->new;
        open my $f, q{<}, $fn or die "Can not read [$fn]!\n";
        $ctx->addfile($f);
        $digest = $ctx->hexdigest;
        close $f;
        $s->d("calculate md5 [$digest]");
        $cache->{$fn} = $digest;
    }
    return $digest;
}

# --- [ dir helpers ] ---------------------------------------------------------
# Deploy::Ningyou::Provider::Rsync
sub compare_dirs {
    my ( $s, $d1, $d2 ) = @_;
    my @rem = ();

    use Carp;
    carp "d1 [$d1] not a directory!\n" if not -d $d1;
    carp "d2 [$d2] not a directory!\n" if not -d $d2;

    my $equal = 1;

    File::DirCompare->compare(
        $d1, $d2,
        sub {
            my ( $a, $b ) = @_;

            # if the callback was called even once, the dirs are not equal
            $equal = 0;
            my $fmt = "  => file '%s' only exists in dir '%s'.";
            if ( !$b ) {
                push @rem, sprintf( $fmt, basename($a), dirname($a) );
            }
            elsif ( !$a ) {
                push @rem, sprintf( $fmt, basename($b), dirname($b) );
            }
            else {
                push @rem, "  => contents for [$a] and [$b] differs.";
            }
        }
    );
    return ( $equal, \@rem );
}

sub loc2mod {
    my ( $s, $loc ) = @_;

    # /srv/ningyou/global/modules/devel/manifests/devel.ini
    $loc =~ m{.*/(.+?)/manifests/(.+?)\.ini$}gmx;
    $s->e( "loc mismatch [$1] ne [$2]", 'bug' ) if $1 ne $2;
    return $1;
}

sub fail {
    my ( $s, $msg ) = @_;
    my $fail = $s->c( 'fail', 'FAIL' );
    my $str = sprintf "[%s] %s", $fail, $msg;
    return $str;
}

sub pass {
    my ( $s, $msg ) = @_;
    my $pass = $s->c( 'pass', 'PASS' );
    my $str = sprintf "[%s] %s", $pass, $msg;
    return $str;
}

no Moose::Role;

1;
__END__

