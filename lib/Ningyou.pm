package Ningyou;

# ABSTRACT: clear reproducible system administration

use utf8;                        # so literals and identifiers can be in UTF-8
use v5.12;                       # or later to get "unicode_strings" feature
use strict;                      # quote strings, declare variables
use warnings;                    # on by default
use warnings qw(FATAL utf8);     # make encoding glitches fatal
use open qw(:std :utf8);         # undeclared streams in UTF-8
use charnames qw(:full :short);  # unneeded in v5.16

use Config::INI::Reader;         #use Config::Any;
use Data::Dumper;
use Encode qw(decode_utf8);
use File::Basename;
use File::Find;
use Moose;
use namespace::autoclean;
use Ningyou::Cmd;
use Ningyou::Util;
use Term::ReadKey;
our $VERSION = '0.0.1';

# ERSION: generated by DZP::OurPkgVersion
#with 'MooseX::SimpleConfig','Ningyou::Debug', 'Ningyou::Out';
with 'Ningyou::Debug', 'Ningyou::Verbose', 'Ningyou::Out';

# command line options
has 'options' => (
    is      => 'rw',
    isa     => 'HashRef',
    reader  => 'get_options',
    writer  => 'set_options',
    default => sub { return {}; },
    lazy    => 1,
);

# global data to store status
my $r = {};    # facts about objects
my $o = {};    # command line options
my $f = {};    # facts about system

my @str        = ();            # commands (in order)
my $str        = {};            # commands
my $info       = {};            # current object information
my $cache      = {};
my $flags      = q{};           # TODO make command line to set it to -y
my $cfg_fn     = q{};
my $wt         = '/dev/null';   # work tree
my $cfg        = {};            # global cfg space
my $pkg        = {};            # pkg from cfg that should be installed or not
my $repository = 'none';
my $provider   = {};            # file, git, ...

sub run {
    my ( $s, $i ) = @_;
    my $u = Ningyou::Util->new;
    $f     = $u->get_facts;
    $o     = $s->get_options;
    $flags = ' -y ' if $o->{mode} eq 'production';
    $s->o( "-" x 78 . "\n" );
    $s->o("Ningyou v$VERSION for [$f->{fqdn}]\n");
    $cfg_fn
        = ( exists $o->{configuration} and defined $o->{configuration} )
        ? $o->{configuration}
        : '~/.ningyou/ningyou.ini';
    $s->o("  use master configuration: $cfg_fn\n");
    $s->o("  use mode: $o->{mode}\n");
    $s->o("  use module: $o->{module}\n") if exists $o->{module};
    $s->o("  use scope: $o->{scope}\n");
    $cfg = $s->get_or_setup_cfg($cfg_fn);

    if ( exists $cfg->{status}->{packages}
        and $cfg->{status}->{packages} eq 'always-update-on-star'
        or exists $o->{update} )
    {
        system('aptitude update');
    }

    $s->o( "-" x 78 . "\n" );
    $s->o("Modules considering for processing:\n");

    my $dot = q{ } . '.' x 70;

    my @modules = ();
    if ( exists $o->{module} ) {
        push @modules, $o->{module};
    }
    else {
        @modules = @{ $s->read_modules() };
    }

    foreach my $mo (@modules) {
        chomp $mo;
        $mo =~ s{^$wt/}{}gmx;    #/home/c/g/wt/modules/zsh -> zsh
        if ( $s->should_be_installed($mo) ) {

            #$s->o("run: add [$mo] to read_ini operation\n");
            $s->o( sprintf( "  %-67.67s [%s]\n", $mo . $dot, ' YES ' ) );
            $s->read_ini($mo);
        }
        else {

            #$s->o("$mo skip installation of [$mo] not in ningyou.ini\n");
            $s->o( sprintf( "  %-67.67s [%s]\n", $mo . $dot, ' NO  ' ) );
        }
    }
    $s->o( "-" x 78 . "\n" );
    $s->query();
    $s->v( "-" x 78 . "\n" );
    my $complexity = $s->validate();
    $s->d( Dumper( \@str ) );
    $s->d( Dumper($str) );
    $s->d( Dumper($info) );
    my $cmd_cnt = scalar @str;

    if ( not $o->{quite} ) {
        $s->o( "-" x 78 . "\n" );
        $s->o("Results:\n");
        $s->v("  complexity: $complexity\n");
        $s->v("  commands:   $cmd_cnt\n");
        if ( $cmd_cnt == 0 ) {
            $s->v("  status: allready up-to-date\n");
            $s->v(
                "  hint: to intall new packages, files, directories, ...,\n");
            $s->v("        add them to '$wt/*/i.ini'\n");
        }
        else {
            $s->v("  status: will perform action\n");
        }
    }
    $s->action($cmd_cnt);
    $s->d("END\n");

    return 1;
}

sub get_or_setup_cfg {
    my ( $s, $cfg_fn ) = @_;

    my $fn = glob $cfg_fn;    # master cfg (~/.ningyou/ningyou.ini)
    my $d  = dirname($fn);
    $s->ask_to_create_directory($d) if not -d $d;
    $s->ask_to_create_default_cfg( $d, $fn ) if not -e $fn;
    $cfg        = Config::INI::Reader->read_file($fn);
    $repository = $s->get_repository( $cfg, $f->{fqdn} );
    $wt         = $s->get_worktree( $cfg, $repository );
    $s->ask_to_create_worktree($wt) if not -d $wt;
    $provider = $cfg->{provider};

    return $cfg;
}

sub get_repository {
    my ( $s, $c, $d ) = @_;    #  c = cfg (master), d = fqdn

    my $m = "ERROR: Node [$d] not mentioned in section [nodes]\n";
    $m .= "Please add node to ningyou.ini\n";
    my $r = exists $c->{nodes}->{$d} ? $c->{nodes}->{$d} : die $m;
    $s->o("  use repository: $r\n") if not $o->{quite};

    return $r;
}

sub get_worktree {
    my ( $s, $c, $r ) = @_;    # c = cfg (master)

    my $se = 'repositories';
    my $m  = "ERROR: '$r' is not mentioned in section [$se]!\n";
    $m .= "Please add repository to ningyou.ini\n";
    my $wt = exists $c->{$se}->{$r} ? $c->{$se}->{$r} : die $m;

    $s->o("  use worktree: $wt\n") if not $o->{quite};

    return $wt;
}

sub ask_to_create_directory {
    my ( $s, $i ) = @_;
    $s->o("The directory [$i] does not exist!\n");
    $s->o("Should the directory be created? [y|N]\n");
    ReadMode('normal');
    my $answer = ReadLine 0;
    chomp $answer;
    ReadMode('normal');

    if ( 'y' eq lc $answer ) {
        my $nilicm = Ningyou::Cmd->new();
        $nilicm->cmd("mkdir -p $i");
        $nilicm->cmd("chown $> $i");    # eff uid $>, real uid $<
            #$nilicm->cmd("chgrp  $) $i");    # eff gid $),     real gid $(
        $nilicm->cmd("chmod 0750 $i");
        $s->o("Directory [$i] has been created.\n");
    }
    else {
        $s->o("Please create it manually (stopping here)\n");
        exit 0;
    }
    $s->o("\n");
    return $i;
}

sub ask_to_create_default_cfg {
    my ( $s, $d, $i ) = @_;

    $s->o("The configuration [$i] do not exist!\n");
    $s->o("Should the configuration be created? [y|N]\n");
    ReadMode('normal');
    my $answer = ReadLine 0;
    chomp $answer;
    ReadMode('normal');

    if ( 'y' eq lc $answer ) {
        my $nilicm = Ningyou::Cmd->new();
        $nilicm->cmd("touch $i");
        $nilicm->cmd("chown $> $i");    # eff uid $>, real uid $<
            #$nilicm->cmd("chgrp $) $i");    # eff gid $),     real gid $(
        $nilicm->cmd("chmod 0640 $i");
        my $wt = "$d/$f->{kernel}-$f->{dist}";
        $s->o("Configuration [$i] has been created.\n");
        open my $f, q{>}, $i or die "Can not open [$i]\n";

        # TODO adopt new cfg
        print $f "[global]\n";
        print $f "kernel=$f->{kernel}\n";
        print $f "distribution=$f->{dist}\n";
        print $f "[$f->{kernel}-$f->{dist}]\n";
        print $f "worktree=$wt/modules\n";
        print $f "[nodes]\n";
        print $f "$f->{fqdn}=$f->{kernel}-$f->{dist}\n";
        close $f;
    }
    else {
        $s->o("Please create it manually (stopping here)\n");
        exit 0;
    }
    $s->o("\n");

}

sub ask_to_create_worktree {
    my ( $s, $i ) = @_;
    $s->o("The worktree do not exists!\n");
    $s->o("Should the directory [$wt] be created? [y|N]\n");
    ReadMode('normal');
    my $answer = ReadLine 0;
    chomp $answer;
    ReadMode('normal');

    if ( 'y' eq lc $answer ) {
        my $nilicm = Ningyou::Cmd->new();
        $nilicm->cmd("mkdir -p $i");
        $nilicm->cmd("chown $> $i");    # eff uid $>, real uid $<
            #$nilicm->cmd("chgrp  $) $i");    # eff gid $),     real gid $(
        $nilicm->cmd("chmod 0750 $i");
        $s->o("Directory [$i] has been created.\n");
    }
    else {
        $s->o("Please create it manually (stopping here)\n");
        exit 0;
    }
    $s->o("\n");

}

sub query {
    my ( $s, $i ) = @_;
    return if $o->{scope} eq 'all';
    $s->v(
        "A query starts, to see what is already provided and what not ...\n");

    foreach my $pr ( sort keys %{$r} ) {    #pr = provider
        $s->v("  examine providor [$pr] ...\n");
        my $m
            = "ERROR: provider [$pr] not supported!\n"
            . "Please install the provider Ningyou::Provider::"
            . ucfirst $pr
            . "\nand consider adding it at"
            . " section [providers] in ningyou.ini\n";
        die $m if not exists $provider->{$pr};
        my $class = "Ningyou::Provider::" . ucfirst $pr;
        eval "use $class";
        die $@ if defined $@ and $@;
        my $p = $provider->{$pr}->new( { options => $o } );
        foreach my $iv ( sort keys %{ $r->{$pr} } ) {    #pr = provider
            $s->v("    do provider [$pr] provide [$iv]?\n");
            my $is_installed = $p->installed(
                {
                    cfg      => $r->{$pr}->{$iv},
                    object   => $iv,
                    provider => $pr,
                    cache    => $cache,
                    wt       => $wt,
                    dryrun   => 1,
                    itemize  => 1,
                    base     => '-a',
                }
            );
            if ($is_installed) {
                $info->{$pr}->{$iv}->{installed} = 1;
                $s->v("    yes, [$iv] allready provied\n");
            }
            else {
                $info->{$pr}->{$iv}->{installed} = 0;
                $s->v("    no, [$iv] not provied\n");
            }
        }
    }

}

sub validate {
    my ( $s, $i ) = @_;

    my $p  = "validate: ";
    my $oq = scalar(@str);
    my $q  = scalar(@str);

    # z = complexity
    my $n = 0;
    $s->v("Validate requirements of provider ...\n");
    foreach my $z ( 0 .. 999999 ) {    # TODO make 99 a cfg val
        $s->v("  entering complexity [$n], command counter [$q]\n");
        $n++;
        $oq = $q;                      # old copy of nr of actions
        $q  = scalar(@str);            # nr of actions
        last if $q == $oq and $q > 0;                # stop if something to do
        last if $q == $oq and $q == 0 and $z > 0;    # stop if nothing todo
        $s->d("z [$z] [$q]\n");

        # pr(object type): file, directory, package
        foreach my $pr ( sort keys %{$r} ) {
            $s->v("  validate requirements of provider [$pr] ...\n");
            next if $pr eq 'default';    # we do not need to install 'default'

            # vi: zsh, /tmp/file, /tmp/dir, ...
            foreach my $iv ( sort keys %{ $r->{$pr} } ) {
                my $mo = $r->{$pr}->{$iv}->{class};    # module
                if ( exists $info->{$pr}->{$iv}->{installed}
                    and $info->{$pr}->{$iv}->{installed} )
                {
                    $s->v(
                        "    [$iv] was allready provieded via [$pr] at [$mo]\n"
                    );
                    next;
                }
                if ( exists $info->{$pr}->{$iv}->{planned}
                    and $info->{$pr}->{$iv}->{planned} )
                {
                    $s->v(
                        "    [$iv] is allready planned via [$pr] at [$mo]\n");
                    next;
                }

                $s->v(
                    "    test [$mo] if it can provide [$iv] via [$pr] ... \n"
                );
                my $so
                    = exists $r->{$pr}->{$iv}->{source}
                    ? $r->{$pr}->{$iv}->{source}
                    : undef;
                $s->v("    source points to [$so]\n") if defined $so;

               # DIRECTORY with SOURCE
               # we want to skip chmod, chown and chgrp  in case source exists
               # (means we use rsync) because chmod,chown and chgrp would be
               # set # to the source owner, which might be not root. In those
               # cases /usr/local might become local user as owner.
                if (    $s->all_require_ok( $pr, $iv )
                    and $pr eq 'directory'
                    and defined $so
                    and exists $info->{$pr}->{$iv}->{installed}
                    and not $info->{$pr}->{$iv}->{installed} )
                {
                    $s->store( $pr, $iv );
                    $s->v(
                        "    yes, it can provide [$iv] to [$so] as [$pr] via rsync\n"
                    );
                    $info->{$pr}->{$iv}->{planned} = 1;
                }
                elsif ($s->all_require_ok( $pr, $iv ) and $pr eq 'directory'
                    or $pr eq 'file'
                    and exists $info->{$pr}->{$iv}->{installed}
                    and not $info->{$pr}->{$iv}->{installed} )
                {
                    if ( defined $so ) {
                        $s->v(
                            "    yes, it can provide [$iv] to [$so] as [$pr]\n"
                        );
                    }
                    else {
                        $s->v("    yes, it can provide [$iv] as [$pr]\n");
                    }
                    $s->store( $pr, $iv );
                    $info->{$pr}->{$iv}->{planned} = 1;
                    if ( exists $r->{$pr}->{$iv}->{ensure}
                        and $r->{$pr}->{$iv}->{ensure} ne 'removed' )
                    {
                        $s->v("    allready done by provider\n");
                    }
                    else {
                        $s->v(
                            "    the provision will be done by [removal]\n");

                    }
                }
                elsif ( $s->all_require_ok( $pr, $iv )
                    and exists $info->{$pr}->{$iv}->{installed}
                    and not $info->{$pr}->{$iv}->{installed} )
                {
                    if ( defined $so and $so ) {
                        $s->v(
                            "    yes, it can provide [$iv] to [$so] as [$pr]\n"
                        );
                    }
                    else {
                        $s->v("    yes, it can provide [$iv] as [$pr]\n");

                    }
                    $s->store( $pr, $iv );
                    $info->{$pr}->{$iv}->{planned} = 1;
                }
                else {
                    $s->v(
                        "    no, dependency not met or is allready provided for [$iv] to [$so] as [$pr]\n"
                    );

                }
            }
        }
    }
    return $n;
}

sub should_be_installed {
    my ( $s, $mo ) = @_;

    return 1 if ( exists $pkg->{$mo} );
    $pkg->{$mo} = 0;

    # if should be installed globally: [packages]
    $pkg->{$mo}++
        if ( exists $cfg->{packages}->{$mo}
        and $cfg->{packages}->{$mo} );

    # if should be installed for repository
    $pkg->{$mo}++
        if ( exists $cfg->{$repository}->{$mo}
        and $cfg->{$repository}->{$mo} );

    # if it should be installed for client
    $pkg->{$mo}++
        if exists $cfg->{ $f->{fqdn} }->{$mo}
            and $cfg->{ $f->{fqdn} }->{$mo};
    return $pkg->{$mo};
}

sub action {
    my ( $s, $complexity ) = @_;

    $s->d( Dumper($str) );
    if ( $o->{script} ) {
        $s->o("#\!/bin/sh\n");
        $s->o("# Ningyou v$VERSION action script\n");
        $s->o("# for [$f->{fqdn}] as [$repository]\n");
        my $cmd_cnt = scalar @str;
        $s->o("# commands: $cmd_cnt\n");
        if ( $complexity == 0 ) {
            $s->o("# nothing to do (already done)\n");
        }
    }
    else {
        if ( $complexity == 0 ) {
            $s->o("Ningyou is already up-to-date.\n");
        }
        else {
            if ( $o->{mode} ne 'dryrun' ) {
                $s->o("  the following commands will be executed:\n");
            }
            else {
                $s->o("  the following commands would be executed:\n");
            }
        }
    }
    my $z = 0;

    foreach my $cmd (@str) {
        if (   $o->{mode} eq 'production'
            or $o->{mode} eq 'interactive' )
        {
            $s->o("execute: [$cmd]\n");
            my $nilicm = Ningyou::Cmd->new();
            $nilicm->cmd($cmd);
        }
        else {
            if ( $o->{script} ) {
                $s->o("$cmd\n");
            }
            else {

                #$s->o( sprintf( "%5d cmd [%s]\n", $z, $cmd ) );
                $s->o( "    " . $cmd );
            }
        }
        $z++;
    }
    if ( $o->{script} ) {
        $s->o("# EOS - end of script\n");
    }

}

sub queue_add {

    #        pr=file   iv=/tmp/x  type=?  cmd=chmod 640 /home/c/.zshrc
    my ( $s, $pr, $iv, $type, $cmd ) = @_;
    if ( $str->{$pr}->{$iv}->{$type} ) {
        $s->d("[$iv] already in queue\n");
    }
    else {
        $s->d("queue add: [$cmd]\n");
        push @str, $cmd;

        # TODO: consider real values
        #$str->{$pr}->{$iv}->{$type} = 1;
        $str->{$pr}->{$iv}->{$type}->{$cmd} = 1;
    }
}

sub store {

    #        pr=object_type, iv=id_value
    #        pr=chown      , iv=/home/c/.zshrc
    #        file           /tmp/c    vim      src
    my ( $s, $pr, $iv ) = @_;
    my $mo
        = exists $r->{$pr}->{$iv}->{class}
        ? $r->{$pr}->{$iv}->{class}
        : die "no pr [$pr], iv [$iv]";

    $s->v("      store [$iv] via [$pr] for [$mo]\n");
    die "Forget to add [$pr] to [provider] in ningyou.ini?\n"
        if not exists $provider->{$pr};

    # This should not be needed:
    #    eval "use $provider->{$pr}";
    #    die $@ if defined $@ and $@;
    my $np  = $provider->{$pr}->new();
    my $cmd = $np->install(
        {

            # mandatory
            cache    => $cache,
            object   => $iv,
            provider => $pr,
            cfg      => $r->{$pr}->{$iv},
            wt       => $wt,

            # rsync
            dryrun  => 0,
            itemize => 0,
        }
    );
    $s->queue_add( $pr, $iv, $pr, $cmd )
        if not $cmd =~ m{^NOP};
}

# queries the 'require' field and deliver all  dependencies
sub get_dependencies {
    my ( $s, $pr, $iv ) = @_;

    # require FIELD format:
    # 1. require=package:zsh
    # 2. require=package:zsh;file=/tmp/zsh
    # 3. require=package:zsh,vim
    # 4. require=package:zsh,vim;file=/tmp/zsh,/tmp/vim

    # split first ";" => require=package:zsh,vim  |  file=/tmp/zsh,/tmp/vim
    my @r     = ();
    my $ident = ' ' x 6;
    my $i
        = exists $r->{$pr}->{$iv}->{require}
        ? $r->{$pr}->{$iv}->{require}
        : return \@r;
    my @p = split /;/, $i;
    foreach my $x (@p) {  # require=package:zsh,vim file=/tmp/zsh,/tmp/vim ...
                          # split NEXT "," => zsh vim tmp/zsh /tmp/vim
        $s->v( $ident . "dep string [$x]\n" );
        my ( $prt, $ivv ) = split /\s*:\s*/, $x;

        # LAST split:
        my @d = ();
        if ( $ivv =~ m/,/gmx ) {    # zsh,vim
            @d = split( /,/, $ivv );
        }
        else {
            push @d, $ivv;          # (no list)
        }
        foreach my $ivvv (@d) {
            $s->v( $ident . "add dependency [$prt] [$ivvv]\n" );
            push @r, { pr => $prt, iv => $ivvv };
        }
    }
    return \@r;

}

sub all_require_ok {
    my ( $s, $pr, $iv ) = @_;

    my $fail = 0;
    foreach my $d ( @{ $s->get_dependencies( $pr, $iv ) } ) {
        my $prt = $d->{pr};
        my $ivv = $d->{iv};
        if ( $s->require_ok( $prt, $ivv ) ) {

        }
        else {
            $fail++;
        }
    }
    return 1 if not $fail;
    return 0;
}

# Decides the question if a dependency via the 'require' field
# is already fulfilled
sub require_ok {
    my ( $s, $pr, $iv ) = @_;
    die "ERROR: require_ok needs pr argument" if not defined $pr;
    die "ERROR: require_ok needs iv argument" if not defined $iv;

    my $ident = ' ' x 6;

    $s->v( $ident
            . "is the requirement for providor [$pr] regarding [$iv] OK?\n" );

    if ( exists $info->{$pr}->{$iv}->{installed} ) {
        $s->d("pass require [$pr]->[$iv] (already installed)\n");
        $s->v( $ident . "pass require [$pr]->[$iv] (already installed)\n" );
        return 1;
    }
    elsif ( exists $str->{$pr}->{$iv}->{pending} ) {
        $s->d("pass require [$pr]->[$iv] (will be installed before)\n");
        $s->v( $ident
                . "pass require [$pr]->[$iv] (will be installed before)\n" );
        return 1;
    }
    elsif ( $iv eq q{} or $pr eq q{} ) {
        die "ERROR 4: ";
    }
    else {
        $s->d("fail require [$pr]->[$iv]\n");
        $s->v( $ident . "fail require [$pr]->[$iv]\n" );
        return 0;
    }
    return 0;
}

sub read_modules {
    my ( $s, $i ) = @_;

    my @m = ();
    find( sub { push @m, "$File::Find::dir$/" if (/manifests$/); }, $wt );
    return \@m;
}

sub read_ini {
    my ( $s, $mo ) = @_;    # mo = module
    my $fn  = "$wt/$mo/manifests/i.ini";
    my $cfg = Config::INI::Reader->read_file($fn);

    # 'default' => {
    #     'file' => {
    #         'checksum' => 'md5',
    #         'owner' => 'c',
    #         'require' => 'package:vim',
    #         'mode' => '644',
    #         'class' => 'vim'
    #      },
    #      'directory' => {
    #         'owner' => 'c',
    #         'require' => 'package:vim',
    #         'mode' => '750',
    #         'class' => 'vim'
    #      }
    # },
    #$s->d( Dumper($cfg) );

    # collect default values first
    my $def = {};
    foreach my $id ( sort keys %{$cfg} ) {    # default:file
        my ( $pr, $iv ) = split /\s*:\s*/, $id;
        $s->d("pr [$pr] iv [$iv]\n");         # pr [default] iv [file]
        next if $pr ne 'default';
        $def->{$iv} = $cfg->{$id};
    }

    # collect all but default values
    foreach my $id ( sort keys %{$cfg} ) {    # file:/tmp/x, package:zsh
        my ( $pr, $iv ) = split /\s*:\s*/, $id;
        $s->d("pr [$pr] iv [$iv]\n");         # pr [file] iv [/tmp/x]
        next if $pr eq 'default';
        $s->d("read_ini: in [$mo] add value [$iv] to object type [$pr]\n");
        if ( exists $r->{$pr}->{$iv} ) {
            my $o   = $r->{$pr}->{$iv}->{class};
            my $msg = "ERRROR 10: overwrite {$pr}->{$iv}!\n";
            $msg .= "ID [$id] already in module [$o]!\n";
            die $msg;
        }
        $r->{$pr}->{$iv} = $cfg->{$id};
        $r->{$pr}->{$iv}->{class} = $mo;

        # add default values
        foreach my $field ( sort keys %{ $def->{$pr} } ) {
            next
                if $field eq 'class';   # class is the same (no def for class)
            $s->d("evaluate default value for field [$field]\n");
            if ( not exists $r->{$pr}->{$iv}->{$field} ) {
                $r->{$pr}->{$iv}->{$field} = $def->{$pr}->{$field};
            }
        }
    }
    $s->d( Dumper($r) );
    $s->d( "def: ", Dumper($def) );
    return $cfg;
}

1;
__END__

=pod

=head1 NAME

Ningyou

=head1 DEPENDENCIES

=head2 DEIBIAN WHEEZY

libterm-readkey
libnamespace-autoclean-perl
libmoose-perl
libcapture-tiny-perl
libconfig-ini-perl

=cut
