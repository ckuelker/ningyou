# +---------------------------------------------------------------------------+
# | Deploy::Ningyou::Provider::Cpan                                           |
# |                                                                           |
# | Provides CPAN deployment                                                  |
# |                                                                           |
# | Version: 0.1.0 (change our $version inside)                               |
# |                                                                           |
# | Changes:                                                                  |
# |                                                                           |
# | 0.1.0 2019-04-21 Christian Kuelker <c@c8i.org>                            |
# |     - initial release                                                     |
# |                                                                           |
# +---------------------------------------------------------------------------+
package Deploy::Ningyou::Provider::Cpan;

# ABSTRACT: Provides CPAN deployment

use Data::Dumper;
use Moose;
use namespace::autoclean;

has 'cmd' => (
    isa     => 'ArrayRef',
    is      => 'rw',
    reader  => 'get_cmd',
    writer  => 'set_cmd',
    default => sub { return []; },
);
has 'dst' => (
    isa     => 'Str',
    is      => 'rw',
    reader  => 'get_dst',
    writer  => 'set_dst',
    default => q{},
);

with qw(
    Deploy::Ningyou::Util
    Deploy::Ningyou::Cfg
    Deploy::Ningyou::Execute
    Deploy::Ningyou::Util::Provider
);

our $version = '0.1.0';

sub register { return 'cpan'; }

sub parameter {
    return { loc => 1, cfg => 1, sec => 1, opt => 1, dry => 0, };
}

sub parameter_description {
    return {
        loc => 'location of the configuration file',
        cfg => 'configuration snippet of a section',
        sec => 'section of the configuration file',
        opt => 'commandline options',
        dry => 'dry run for ::Script',
    };
}

sub parameter_default { return { dry => 1 }; }

sub attribute {
    return {
        comment     => 0,
        download    => 0,
        ensure      => 0,
        environment => 0,
        require     => 0,
        source      => 1,
    };
}

sub attribute_default {
    return {
        comment     => 0,
        download    => 0,
        ensure      => 'present',
        environment => 0,
        require     => 0,
        source      => 0,
    };
}

sub attribute_description {
    return {
        checksum    => 'file need to match this check sum',
        comment     => 'test, not used the moment',
        ensure      => 'latest|present|missing',
        environment => 'bash environment to be sourced in',
        require     => 'require this other entity (provider)',
        source      => 'source file in the worktree',
        download    => 'download url',
    };
}

sub script { return 0; }
sub init   { return 1; }
sub apply  { my ( $s, $i ) = @_; return $s->standard_apply($i); }

# IN:
#   cfg: module section configuration                          HASH
#   loc: /srv/ningyou/global/modules/devel/manifests/devel.ini HASH
#   sec: global:file:/home/c/.perltidyrc                       STR
#   opt: { 'verbose' => 1 }                                    HASH
#   dry: 0                                                     BOOL
sub applied {
    my ( $s, $i ) = @_;

    my ( $v, $sec, $cls, $prv, $dst, $cfg, $c, $loc, $ok )
        = $s->applied_in( { i => $i } );
    $s->e( 'section is not OK', 'cfg' ) if not $ok;

    my $return = 0;

    #my @cmd   = @{$s->get_cmd};
    my @cmd = ();                          # trow away standard small prv_info
    my $sec_c = $s->c( 'section', $sec );
    my $mod_c = $s->c( 'module', $s->loc2mod( $i->{loc} ) );
    my $str   = "section [$sec_c]";
    $s->d( $s->pass($str) . "\n" );

    # test if module is installed
    my $env
        = (     exists $cfg->{environment}
            and defined $cfg->{environment}
            and $cfg->{environment} )
        ? "source $cfg->{environment}&&"
        : q{};
    my $cmd_perl = "perl -M$dst -e 1 >/dev/null 2>&1";
    my $cmd_bash = qq{bash -c '$env$cmd_perl'};
    $s->d("# $cmd_bash\n");
    my ( $out0, $err0, $test_installed ) = $s->evaluate_quite($cmd_bash);

    # get current version
    my $cmd_cvp = qq{perl -M$dst -le "print STDOUT \\\$${dst}::VERSION;"};
    my $cmd_cvb = qq{bash -c '$env$cmd_cvp'};
    my ( $cv, $err1, $res1 ) = $s->evaluate_quite($cmd_cvb);
    chomp $cv;
    use version;
    my $cvn
        = $cv eq q{}
        ? version->declare(0)->numify
        : version->declare($cv)->numify;
    $s->d("cvn[$cvn]");

    # get remote version
    my $cmd_lvb = qq{cpanm --info $dst};
    my ( $cpan_info, $err2, $res2 ) = $s->evaluate_quite($cmd_lvb);
    chomp $cpan_info;
    my $tar = 'tar.Z|tar.gz|tgz|tar.bz2|tbz2|tbz|tar.xz|txz|tar.lzma';
    $tar =~ s{\.}{\\.}gmx;
    $cpan_info =~ m{.*/.*-(.*)\.($tar)}gmx;    # NAME/MODULE-VERSION.POSTFIX
    chomp( my $lv = $1 );
    my $lvn
        = $lv eq q{}
        ? version->declare(0)->numify
        : version->declare($lv)->numify;
    $s->d("lvn[$lvn]");

    my $latest
        = ( defined $lvn and defined $cvn and $cvn and $lvn and $cvn >= $lvn )
        ? 1
        : 0;

    # update info
    my $info = { %{ $i->{cfg} } };    # shallow copy is enough
    $info->{section}              = $sec_c;
    $info->{module}               = $mod_c;
    $info->{class}                = $cls;
    $info->{provider}             = $prv;
    $info->{latest}               = $latest ? 'yes' : 'no';
    $info->{current_version}      = $cv if defined $cv;
    $info->{current_perl_version} = $cvn;
    $info->{latest_version}       = $lv if defined $lv;
    $info->{latest_perl_version}  = $lvn;
    push @cmd, $s->prv_info($info) if $v;

    my $pfx = "  => [" . $s->register . "]";

    # commands
    my $source
        = exists $cfg->{source}
        ? $cfg->{source}
        : $s->e( "no source attr", 'cfg' );

    # cpanm
    # ensure=present: skips latest version if installed
    my $cm_flag
        = $cfg->{ensure} eq 'present' ? '--skip-satisfied'
        : $cfg->{ensure} eq 'missing' ? '--uninstall --force'
        :                               q{};
    my $url
        = (     exists $cfg->{download}
            and defined $cfg->{download}
            and $cfg->{download} ) ? $cfg->{download} : 0;
    my $wt      = $s->get_worktree;
    my $src     = $s->url( $wt, $source );
    my $cmd_src = qq{bash -c '${env}cpanm $cm_flag $src'};
    my $cmd_wget
        = qq{wget --continue --no-clobber --output-document '$src' $url};

    if (   ( $test_installed > 1 and not $cfg->{ensure} eq 'missing' )
        or ( $cfg->{ensure} eq 'latest' and not $latest ) )
    {    # module not installed
        $s->d("# $dst is not installed\n");

        # OVERVIEW:
        # 1 if source is a file and download and source not there:
        #   download it, install it
        # 2 elsif source is a file and file exists: install it
        # 3 elsif source is a file and file not  exists: error
        # 4 else install it
        if ( $src =~ m{^/} and $url and not -f $src ) {    # 1
            push @cmd, { verbose => "$pfx download $url" };
            push @cmd, { verbose => "$pfx install $src" };
            push @cmd, { cmd     => $cmd_wget };
            push @cmd, { cmd     => $cmd_src };
        }
        elsif ( $src =~ m{^/} and -f $src ) {              # 2
            push @cmd, { verbose => "$pfx install it $src" };
            push @cmd, { cmd     => $cmd_src };
        }
        elsif ( $src =~ m{^/} and not -f $src ) {          # 3
            $s->e( "No file [$src]", 'cfg' );
        }
        else {                                             # 4
            push @cmd, { verbose => "$pfx install from URL $src" };
            push @cmd, { cmd     => $cmd_src };
        }
    }
    else {
        # OVERVIEW
        # 1 if missing and have current version: remove
        # 2 if missing and not have current version: already removed
        # 3 else: allready installed
        if ( $cfg->{ensure} eq 'missing' and $cv ) {
            push @cmd, { verbose => "$pfx remove $sec]" };
            push @cmd, { cmd     => $cmd_src };
        }
        elsif ( $cfg->{ensure} eq 'missing' and not $cv ) {
            push @cmd, { verbose => "$pfx $sec is already removed" };

        }
        else {
            push @cmd, { verbose => "$pfx $dst is already installed" };
            $return = 1;    # installed
        }
    }
    $return = 0;

    $s->set_cmd( \@cmd );
    return $return;
}

__PACKAGE__->meta->make_immutable;

1;
__END__

