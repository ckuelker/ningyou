# +---------------------------------------------------------------------------+
# | Deploy::Ningyou::Action::Bootstrap                                        |
# |                                                                           |
# | Provides bootstrap argument action                                        |
# |                                                                           |
# | Version: 0.1.0 (change our $version inside)                               |
# |                                                                           |
# | Changes:                                                                  |
# |                                                                           |
# | 0.1.0 2019-03-28 Christian Kuelker <c@c8i.org>                            |
# |     - initial release                                                     |
# |                                                                           |
# +---------------------------------------------------------------------------+
package Deploy::Ningyou::Action::Bootstrap;

# ABSTRACT: Provides bootstrap argument action

use Cwd qw(cwd);
use Data::Dumper;
use File::Touch;
use Moose;
use namespace::autoclean;
use Template;
use Deploy::Ningyou::Facter;

has 'ini' => (
    isa    => 'Config::Tiny',
    is     => 'ro',
    reader => 'get_ini',
    writer => '_set_ini',

    #required=> 1, do not seem to work with Module::Pluggable
);

with
    qw(Deploy::Ningyou::Util Deploy::Ningyou::Util::Action Deploy::Ningyou::Host);

our $version = '0.1.0';

# === [ main ] ================================================================
sub register { return 'bootstrap'; }

# subroutine input options
# parameter => 1=mandatory|0=optional
sub parameter             { return { opt => 1 }; }
sub parameter_description { return { opt => 'commandline options' }; }

# configuration input options
# param => description
sub attribute             { return {}; }
sub attribute_description { return {}; }

sub apply {
    my ( $s, $i ) = @_;
    my $opt = exists $i->{opt} ? $i->{opt} : $s->e( "no [opt]", 'sp' );

    # 1. check configuration is NOT present
    my $fn = "$ENV{HOME}/.ningyou.ini";
    $s->e( "Configuration already present [$fn]", 'removing' ) if -f $fn;
    $s->p("Using configuration file name [$fn]\n");

    # 2. create main configuration
    touch( ($fn) ) or $s->e( "$!! Can not create [$fn]", 'permission' );
    $s->e( "$!! Can not create [$fn]", 'permission' ) if not -f $fn;
    my $fqhn = $s->get_facter_fqhn;              # fully qualified host name
    my $nf   = Deploy::Ningyou::Facter->new();
    my $dist = $nf->get_facter_distribution;
    my $dir  = cwd
        or $s->e( "Can not change to current directory", 'no_dir' );
    $dir .= '/ningyou';
    my %config = (
        VARIABLES => {
            PROJECT       => $s->get_project_version,
            CONFIGURATION => $s->get_configuration_version,
            DISTRIBUTION  => $dist,
            WORKTREE      => $dir,
            FQHN          => $fqhn,
        }
    );
    my $mt    = Template->new( \%config ) || die Template->error(), "\n";
    my $mtpl  = $s->ningyou_ini();
    my $mvars = { VERSION => $Deploy::Ningyou::Action::Bootstrap::VERSION, };
    my $mr = $mt->process( \$mtpl, $mvars, $fn ) || die $s->e( $mt->error() );
    $s->e( "Problem found when creating $fn", 'permission' ) if not $mr;
    $s->p("Created configuration file [$fn]\n") if $mr;

    my $sw = 'main-configuration-only';
    return 1 if exists $opt->{$sw} and $opt->{$sw};

    # 3. check work tree is NOT present
    $s->e( "Work tree already present [$dir]", 'removing' ) if -d $dir;
    $s->p("Bootstrapping Ningyou to work tree [$dir]\n");

    # 4. create work tree
    mkdir $dir;
    my $mode = 0750;
    chmod $mode, $dir;
    $s->e( "$!! Can not create [$dir]", 'permission' ) if not -d $dir;
    $s->p("Created work tree [$dir]\n") if -d $dir;

    # 5. create distribution
    my $rep = "$dir/$dist";
    mkdir $rep;
    chmod $s->e( "$!! Can not create [$rep]", 'permission' )
        if not -d $rep;
    $s->p("Created distribution [$rep]\n") if -d $rep;

    # 6. git init
    my $cmd = qq{cd $dir && git init};
    my @o   = qx($cmd)
        or die $s->e( "$!! Can not initialize git repository", 'permission' );
    foreach my $o (@o) { $s->p($o); }

    # 7. create host configuration
    my $hfn = "$dir/$fqhn.ini";
    $s->p("Using host file name [$hfn]\n");
    my $ht    = Template->new( \%config ) || die Template->error(), "\n";
    my $htpl  = $s->host_ini();
    my $hvars = { VERSION => $Deploy::Ningyou::Action::Bootstrap::VERSION, };
    my $hr    = $mt->process( \$htpl, $hvars, $hfn )
        || die $s->e( $ht->error() );
    $s->e( "Problem found when creating $hfn", 'permission' ) if not $hr;
    $s->p("Created host file [$hfn]\n") if $hr;
    my $hcmd
        = qq{cd $dir&&git add $hfn;git commit -m "+ host configuration $fqhn" $hfn};
    $s->d($hcmd);
    my $ho = qx($hcmd);
    $s->p($ho);

    # 8. create more directories
    my @dir = ();
    push @dir, "$dir/global";
    push @dir, "$dir/global/modules";
    push @dir, "$dir/global/modules/default";
    push @dir, "$dir/global/modules/default/files";
    push @dir, "$dir/global/modules/default/manifests";
    push @dir, "$rep/modules";
    push @dir, "$rep/modules/default";
    push @dir, "$rep/modules/default/files";
    push @dir, "$rep/modules/default/manifests";
    push @dir, "$dir/$fqhn";
    push @dir, "$dir/$fqhn/modules";
    push @dir, "$dir/$fqhn/modules/default";
    push @dir, "$dir/$fqhn/modules/default/files";
    push @dir, "$dir/$fqhn/modules/default/manifests";
    foreach my $d (@dir) {
        $s->p("Crate directory [$d]\n");
        mkdir $d;
        $s->e( "$!! Can not create [$d]", 'permission' ) if not -d $d;
    }

    # 9. create default module at 3 locations
    my @default = (
        "$dir/global/modules/default/manifests/default.ini",
        "$rep/modules/default/manifests/default.ini",
        "$dir/$fqhn/modules/default/manifests/default.ini",
    );
    foreach my $dfn (@default) {
        $s->p("Using default manifest file name [$dfn]\n");
        my $dt = Template->new( \%config ) || die Template->error(), "\n";
        my $dtpl = $s->default_ini();
        my $dvars = { VERSION => $Deploy::Ningyou::Action::Bootstrap::VERSION, FILENAME => $dfn };
        my $dr = $dt->process( \$dtpl, $dvars, $dfn )
            || die $s->e( $dt->error() );
        $s->e( "Problem found when creating $dfn", 'permission' ) if not $dr;
        $s->p("Created manifest file [$dfn]\n") if $dr;
        my $dcmd
            = qq{cd $dir&&git add $dfn;git commit -m "+ module manifest $dfn" $dfn};
        $s->d($dcmd);
        my $do = qx($dcmd);
        $s->p($do);
    }

    return 1;
}

sub ningyou_ini {

    return <<'END_INI';
; +---------------------------------------------------------------------------+
; | ningyou.ini => ~/.ningyou.ini                                             |
; |                                                                           |
; | Main configuration for Ningyou                                            |
; |                                                                           |
; | Version: 0.1.0 (Change also inline: [version] file=)                      |
; |                                                                           |
; | Changes:                                                                  |
; |                                                                           |
; | 0.1.0 2019-03-28 Christian Kuelker <c@c8i.org>                            |
; |     - initial release                                                     |
; |                                                                           |
; +---------------------------------------------------------------------------+
;
; Valid sections are: [version], [global]
;
; Valid parameters for section [version]: project, configuration, file
;
; Valid parameters for section [global]: worktree
;
[version]
; Ningyou Project version - changed by Ningyou
project=[% PROJECT %]
; Ningyou Configuration Space version - changed by Ningyou
configuration=[% CONFIGURATION %]
; version of this file - change this when you update the file
file=0.1.0

[global]
worktree=[% WORKTREE %]

[system]
fqhn=[% FQHN %]

[os]
distribution=[% DISTRIBUTION %]
; package manager cache time to live, default 3600 = 1h
pm_cache_ttl=3600

END_INI

}

sub host_ini {

    return <<'END_HOST_INI';
; +---------------------------------------------------------------------------+
; | host.ini (actual name is FQHN)                                            |
; |                                                                           |
; | Configuration for one host                                                |
; |                                                                           |
; | Version: 0.1.0 (Change also inline: [version] file=)                      |
; |                                                                           |
; | Changes:                                                                  |
; |                                                                           |
; | 0.1.0 2019-03-30 Christian Kuelker <c@c8i.org>                            |
; |     - initial release                                                     |
; |                                                                           |
; +---------------------------------------------------------------------------+
[version]
; Ningyou Project version - changed by Ningyou
project=[% PROJECT %]
; Ningyou Configuration Space version - changed by Ningyou
configuration=[% CONFIGURATION %]
; version of this file - change this when you update the file
file=0.1.0

[global]
; distribution independent modules
; active modules = 1
; inactive modules = 0
; dummy default module present
default=1

[[% DISTRIBUTION %]]
; distribution [% DISTRIBUTION %] dependent modules
; dummy default module present
default=1

[[% FQHN %]]
; host [% FQHN %] dependent modules
; dummy default module present
default=1

END_HOST_INI

}

sub default_ini {

    return <<'DEFAULT_INI';
; +---------------------------------------------------------------------------+
; | modules/default/manifests/default.ini                                     |
; |                                                                           |
; | Configuration for default module.                                         |
; |                                                                           |
; | Version: 0.1.0 (Change also inline: [version] file=)                      |
; |                                                                           |
; | Changes:                                                                  |
; |                                                                           |
; | 0.1.0 2019-03-30 Christian Kuelker <c@c8i.org>                            |
; |     - initial release                                                     |
; |                                                                           |
; +---------------------------------------------------------------------------+
;
[version:default]
; Ningyou Project version - changed by Ningyou
project=[% PROJECT %]
; Ningyou Configuration Space version - changed by Ningyou
configuration=[% CONFIGURATION %]
; version of this file - change this when you update the file
file=0.1.0

[nop:default]
; the 'nop' provider provides a 'no operation' - nothing
; can be used to check (via debug) if configuration section is actually used
debug=NOP default [% FILENAME %]

DEFAULT_INI

}

__PACKAGE__->meta->make_immutable;

1;
__END__

