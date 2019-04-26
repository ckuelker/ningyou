# +---------------------------------------------------------------------------+
# | Deploy::Ningyou::Provider::Package                                        |
# |                                                                           |
# | Provides package deployment                                               |
# |                                                                           |
# | Version: 0.1.0 (change our $version inside)                               |
# |                                                                           |
# | Changes:                                                                  |
# |                                                                           |
# | 0.1.0 2019-04-02 Christian Kuelker <c@c8i.org>                            |
# |     - initial release                                                     |
# |                                                                           |
# +---------------------------------------------------------------------------+
package Deploy::Ningyou::Provider::Package;

# ABSTRACT: Provides package deployment

use AptPkg::Config '$_config';
use AptPkg::System '$_system';
use AptPkg::Version;
use Data::Dumper;
use Moose;
use namespace::autoclean;

our $version = '0.1.0';
our $CACHE   = {};

has 'cmd' => (
    isa     => 'ArrayRef',
    is      => 'rw',
    reader  => 'get_cmd',
    writer  => 'set_cmd',
    default => sub { return []; },
);

has 'cache' => (
    is      => 'rw',
    isa     => 'HashRef',
    reader  => 'get_cache',
    writer  => 'set_cache',
    builder => 'cache',
    lazy    => 1,
);
has 'opt' => (
    isa     => 'Str',
    is      => 'rw',
    reader  => 'get_opt',
    writer  => 'set_opt',
    default => sub {'--assume-yes'},
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
sub register { return 'package'; }

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
        source  => 0,
        ensure  => 1,
        require => 0,
        comment => 0,
        version => 0
    };
}

sub attribute_default {
    return {
        source  => 0,
        ensure  => 'present',
        require => 0,
        comment => '',
        version => 0,
    };
}

# module configuration attributes
#   [package:vim]
#   source   = ningyou://~/vim.deb
#   source   = ningyou://global/modules/vim/files/vim.deb
#   source   = /srv/packages/vim.deb
#   ensure   = latest|present|missing
#   require  = package:zsh,package:tree
# provided by Deploy::Ningyou::Attribute::*
sub attribute_description {
    return {
        source  => 'source package in the worktree',
        ensure  => 'latest|present|missing',
        require => 'require this other entity (provider)',
        comment => 'comment',
        version => 'package version',
    };
}    # param => description

# cache
# IN:
# OUT:
#     cache
# FORMAT:
# ...
#    'libxom-java' => {
#       'version' => '1.2.10-1',
#       'status' => 'install ok installed'
#       'upgradable' => '1.2.11-1',
#    },
# ...
sub cache {
    my ( $s, $i ) = @_;
    my $cache_full = scalar keys %{$CACHE};
    return $CACHE if $cache_full;
    my $r   = {};
    my $cmd = '/usr/bin/dpkg-query';

    # install ok installed;libvpx4;1.6.1-3+deb9u1
    # rpm -qa --qf '%{INSTALLTIME};%{NAME};%{VERSION}-%{RELEASE}
    my @q = qx($cmd -W --showformat '\${Status};\${Package};\${Version}\\n');
    $s->d("init");
    foreach my $q (@q) {
        chomp $q;

        # install ok applied;xsltproc;1.1.26-6+squeeze3
        my ( $status, $package, $version ) = split /;/, $q;
        my $e = "unknown status - update Deploy::Ningyou::Provider::Package";
        $s->e( $e, 'bug' ) if $status ne 'install ok installed';
        $r->{package}->{$package}->{version} = $version;
        $r->{package}->{$package}->{status}  = $status; # install ok installed
    }

# Listing... Done
# ...
# ruby2.3/stable 2.3.3-1+deb9u6 amd64 [upgradable from: 2.3.3-1+deb9u4]
# tree/stable 1.7.0-5 amd64 [upgradable from: 1.7.0-3]
#my @o = qx(apt  list --upgradable);
#$o=~m{(.*?)/.*upgradable\s+from:\s+(.*)]}gmx;
#
# ...
# Inst tree [1.7.0-3] (1.7.0-5 Debian:9.8/stable [amd64])
# Inst ruby2.3 [2.3.3-1+deb9u4] (2.3.3-1+deb9u6 Debian-Security:9/stable [amd64])
    my @o = qx(apt-get --just-print upgrade|grep Inst);
    foreach my $o (@o) {
        $o =~ m{Inst\s+(.*)\s+\[.*\((.*?)\s+}gmx;
        my $package = $1;
        my $version = $2;
        $s->d("package [$package] upgradable to [$version]");
        $r->{package}->{$package}->{upgradable} = $version;
        $s->e( 'upgradable package without version', 'cfg' )
            if not exists $r->{package}->{$package}->{version};
        $s->d($o);
    }
    $s->set_cache($r);
    $CACHE = $r;

    #print Dumper($CACHE);
    return $r;
}

sub init { my ( $s, $i ) = @_; my $cache = $s->get_cache; return 1; }
sub script { return 0; }

sub apply { my ( $s, $i ) = @_; return $s->standard_apply($i); }

# applied
# IN:
# OUT:
#  0|1
#
sub applied {
    my ( $s, $i ) = @_;

    # verbose section class provider destination
    my ( $v, $sec, $cls, $prv, $dst, $cfg, $c, $loc, $ok )
        = $s->applied_in( { i => $i } );
    $s->e( 'section is not OK', 'cfg' ) if not $ok;

    # package version helpers
    $_config->init;
    $_system = $_config->system;
    my $vs = $_system->versioning;

    # from cache
    my $cache = $s->get_cache;
    my $cv
        = exists $cache->{$prv}->{$dst}->{version}
        ? $cache->{$prv}->{$dst}->{version}
        : 0;
    my $nv
        = exists $cache->{$prv}->{$dst}->{upgradable}
        ? $cache->{$prv}->{$dst}->{upgradable}
        : 0;

    # descision tree
    my @cmd    = @{ $s->get_cmd };    # set by applied_in
    my $return = 0;
    if ( $c->{source} and $c->{version} ) {
        $s->e( 'Attribute [source] are [version] incompatibe', 'cfg' );
    }
    elsif ( $c->{source} ) {
        $s->d("package $dst has source [$c->{source}]");
        if ( $c->{ensure} eq 'latest' ) {
            $s->e( 'Attribute [source] contradicts ensure=latest', 'cfg' );
        }
        elsif ( $c->{ensure} eq 'present' ) {
            if ($cv) {
                $s->d("package $dst has source $c->{source} we have $cv");
                $return = 1;
            }
            else {
                my $r = "install last resort package";
                push @cmd, $s->inject( { r => $r, s => $c->{source} } );
            }
        }
        elsif ( $c->{ensure} eq 'missing' ) {
            $s->e( 'Attribute [source] contradicts ensure=missing', 'cfg' );
        }
        else {
            $s->e( "Unknown value ensure=$c->{ensure}", 'cfg' );
        }
    }
    elsif ( $c->{version} ) {
        $s->d("package $dst has version [$c->{version}]");
        if ( $c->{ensure} eq 'latest' ) {
            $s->e( 'Attribute [version] contradicts ensure=latest', 'cfg' );
        }
        elsif ( $c->{ensure} eq 'present' ) {
            if ($cv) {
                if ( $vs->compare( $cv, $c->{version} ) > 0 ) {
                    $s->d("$dst has $cv > $c->{version} => DOWNGRADE");
                    my $r1 = "present $cv > $c->{version}: downgrade 1. step";
                    push @cmd, $s->uninstall( { r => $r1 } );
                    my $r2 = "present $cv > $c->{version}: downgrade 2. step";
                    push @cmd,
                        $s->install( { r => $r2, v => $c->{version} } );
                }
                elsif ( $vs->compare( $cv, $c->{version} ) < 0 ) {
                    $s->d("present $dst has $cv < $c->{version} => UPDATE");
                    my $r = "latest cv $cv < $c->{version} => update";
                    push @cmd, $s->install( { r => $r, v => $c->{version} } );
                }
                else {
                    $s->d("present $dst has $cv = $c->{version}");
                    $return = 1;
                }
            }
            else {
                my $r = 'fixed version package';
                push @cmd, $s->install( { r => $r, v => $c->{version} } );
            }
        }
        elsif ( $c->{ensure} eq 'missing' ) {
            $s->e( 'Attribute [version] contradicts ensure=missing', 'cfg' );
        }
        else {
            $s->e( "Unknown value ensure=$c->{ensure}", 'cfg' );
        }
    }
    elsif ( not $c->{version} and not $s->{source} ) {
        $s->d("package $dst has no version and no source");
        if ( $c->{ensure} eq 'latest' ) {
            $s->d("package $dst has ensure=latest");
            if ($cv) {
                if ( $nv and $vs->compare( $cv, $nv ) > 0 ) {
                    $s->d("package $dst has $cv > $nv => DOWNGRADE");
                    my $r1 = "latest cv $cv > $nv: downgrade (1. step)";
                    push @cmd, $s->uninstall( { r => $r1 } );
                    my $r2 = "latest cv $cv > $nv: downgrade (2. step)";
                    push @cmd, $s->install( { r => $r2 } );
                }
                elsif ( $nv and $vs->compare( $cv, $nv ) < 0 ) {
                    $s->d("latest $dst has $cv < $nv => UPDATE");
                    my $r = "latest cv $cv < $nv: update";
                    push @cmd, $s->install( { r => $r } );
                }
                elsif ( $nv and $vs->compare( $cv, $nv ) == 0 ) {
                    $s->d("latest $dst has $cv = $nv");
                    $return = 1;
                }
                else {
                    $s->d("package has no upgradable version");
                    my $r = 'latest & no upgradable version => applied?';
                    push @cmd, { verbose => $r };
                    $return = 1;
                }
            }
            else {
                push @cmd,
                    $s->install( { r => "latest & no current version" } );
            }
        }
        elsif ( $c->{ensure} eq 'present' ) {
            if ($cv) {
                $return = 1;
            }
            else {
                my $r = "present & no current version";
                push @cmd, $s->install( { r => $r } );
            }
        }
        elsif ( $c->{ensure} eq 'missing' ) {
            if ($cv) {
                push @cmd, $s->purge( { r => "missing & current version" } );
            }
            else {
                $return = 1;
            }
        }
        else {
            $s->e( "Unknown value ensure=$c->{ensure}", 'cfg' );
        }
    }
    else {
        $s->e( 'Unknown condition in provider [package]', 'bug' );
    }
    $s->set_cmd( \@cmd );
    return $return;
}

sub install {
    my ( $s, $i ) = @_;
    $i = $s->validate_parameter( { r => 1, v => 0 }, $i, { v => 0 } );
    my $dst = $s->get_dst;
    $i->{r} = " install $dst: $i->{r}";
    $s->d("$i->{r}");
    my $opt = $s->get_opt;
    my $cmd = "aptitude $opt install $dst";
    $cmd = "$cmd=$i->{v}" if $i->{v};
    return { cmd => $cmd, verbose => $i->{r} };
}

sub uninstall {
    my ( $s, $i ) = @_;
    $i = $s->validate_parameter( { r => 1 }, $i, {} );
    $i->{r} = "  uninstall " . $s->get_dst . ": $i->{r}";
    $s->d("$i->{r}");
    my $cmd = "aptitude " . $s->get_opt . " uninstall " . $s->get_dst;
    return { cmd => $cmd, verbose => $i->{r} };
}

sub purge {
    my ( $s, $i ) = @_;
    $i = $s->validate_parameter( { r => 1, v => 0 }, $i, { v => 0 } );
    $i->{r} = "  purge " . $s->get_dst . ": $i->{r}";
    $s->d("$i->{r}");
    my $cmd = "aptitude " . $s->get_opt . " purge " . $s->get_dst;
    return { cmd => $cmd, verbose => $i->{r} };
}

sub inject {
    my ( $s, $i ) = @_;
    $i = $s->validate_parameter( { r => 1, s => 1 }, $i, {} );
    $i->{r} = "  install, inject " . $s->get_dst . ": $i->{r}";
    $s->d("$i->{r}");
    my $cmd = "dpkg -i $i->{s}";
    return { cmd => $cmd, verbose => $i->{r} };
}

1;
__PACKAGE__->meta->make_immutable;
__END__
