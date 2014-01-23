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
use Ningyou::Options;
use Ningyou::Type::Module;
our $VERSION = '0.0.9';

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

has 'provided' => (
    traits  => ['Hash'],
    is      => 'rw',
    isa     => 'HashRef[Bool]',
    default => sub { return { 'package:ningyou' => 1 }; },
    handles => {
        has_provided    => 'exists',
        is_provided     => 'defined',
        ids_provided    => 'keys',
        get_provided    => 'get',
        set_provided    => 'set',
        num_provided    => 'count',
        is_not_provided => 'is_empty',
        del_provided    => 'delete',
        provided_pairs  => 'kv',
    },
);
has 'planned' => (
    traits  => ['Hash'],
    is      => 'rw',
    isa     => 'HashRef[Bool]',
    default => sub { return {}; },
    handles => {
        has_planned    => 'exists',
        is_planned     => 'defined',
        ids_planned    => 'keys',
        get_planned    => 'get',
        set_planned    => 'set',
        num_planned    => 'count',
        is_not_planned => 'is_empty',
        del_planned    => 'delete',
        planned_pairs  => 'kv',
    },
);

has 'command' => (
    traits  => ['Array'],
    is      => 'rw',
    isa     => 'ArrayRef[Str]',
    default => sub { return []; },
    handles => {
        all_commands    => 'elements',
        add_command     => 'push',
        map_commands    => 'map',
        filter_commands => 'grep',
        find_command    => 'first',
        get_command     => 'get',
        join_commands   => 'join',
        count_commands  => 'count',
        has_commands    => 'count',
        has_no_commands => 'is_empty',
        sorted_commands => 'sort',
    },
);

# 'directory:/home/c/bin',
#     bless( {
#         module => {
#            'owner' => 'c',
#            'source' => 'ningyou:///modules/home-bin/bin',
#            'require' => 'package:zsh',
#            'mode' => 'Fo-x',
#            'group' => 'c',
#            'recurse' => 'true',
#            'purge' => '1',
#            'module' => 'home-bin'
#        }
#    }, 'Ningyou::Type::Module' )
has 'cfg' => (
    traits  => ['Hash'],
    is      => 'rw',
    isa     => 'HashRef[Ningyou::Type::Module]',
    default => sub { return {}; },
    handles => {
        has_cfg    => 'exists',
        is_cfg     => 'defined',
        ids_cfg    => 'keys',
        get_cfg    => 'get',
        set_cfg    => 'set',
        num_cfg    => 'count',
        is_not_cfg => 'is_empty',
        del_cfg    => 'delete',
        cfg_pairs  => 'kv',
    },
);

has 'master' => (
    traits  => ['Hash'],
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { return {}; },
    handles => {
        has_master    => 'exists',
        is_master     => 'defined',
        ids_master    => 'keys',
        get_master    => 'get',
        set_master    => 'set',
        num_master    => 'count',
        is_not_master => 'is_empty',
        del_master    => 'delete',
        master_pairs  => 'kv',
    },
);

# global data

# global data to store status
my $mode       = q{};            # command
my $modules_ar = [];             # modules
my $modules    = q{};            # modules
my $result     = {};             # modules
my $f          = {};             # facts about system
my $cache      = {};
my $wt         = '/dev/null';    # work tree
my $cfg        = {};             # global cfg space
my $pkg        = {};             # pkg from cfg that should be applied or not
my $repository = 'none';
my $provider   = {};             # file, git, ...

sub run {
    my ( $s, $i ) = @_;

    # prepare options
    my $opt = Ningyou::Options->new;
    $opt->process_options;
    my $o = $opt->get_options;
    $s->set_options($o);         # set for Ningyou::Out ...
    $mode       = $opt->get_command;
    $modules_ar = $opt->modules;
    $modules    = join q{ }, @{$modules_ar};

    # prepare facts
    my $u = Ningyou::Util->new;
    $f = $u->get_facts;

    # prepare configuration
    my $cfg_fn
        = ( exists $o->{configuration} and defined $o->{configuration} )
        ? $o->{configuration}
        : '~/.ningyou/master.ini';
    $cfg = $s->get_or_setup_cfg( $cfg_fn, $u );

    # update system package meta data
    if ( exists $cfg->{status}->{packages}
        and $cfg->{status}->{packages} eq 'always-update-on-start'
        or exists $o->{update} )
    {
        system('aptitude update');
    }

    # print preamble
    # $s->o( "=" x ( 78 - $o->{indentation} ) . "\n" );
    $mode = ( $mode eq q{} ) ? 'show' : $mode;
    my $comment = ( $mode eq 'script' ) ? '# ' : q{};
    $s->o("#!/bin/sh\n") if $mode eq 'script';
    $s->o(    $comment
            . 'Ningyou '
            . $s->c( 'version', "v$VERSION" ) . " for "
            . $s->c( 'host',    $f->{fqdn} )
            . ' with configuration '
            . $s->c( 'file', $cfg_fn )
            . "\n" );

    my $str = ( not defined $modules or $modules eq q{} ) ? 'all' : $modules;
    $s->o(    $comment
            . $s->c( 'mode', ucfirst($mode) )
            . " module(s) "
            . $s->c( 'module', $str ) . " in "
            . $s->c( 'file',   $wt )
            . "\n" );

    # prepare print used modules
    my $dot = q{ } . '.' x 70;
    my $dl  = 68 - $o->{indentation};

    # print used modules and read its configuration
    #$s->o( "=" x ( 78 - $o->{indentation} ) . "\n" );
    $s->v("Modules concidered processing: (switch on/off via master.ini)\n");
    my @modules = ();
    if ( $modules ne q{} and $modules ne 'all' ) {
        @modules = @{$modules_ar};
    }
    else {
        @modules = @{ $s->read_modules() };
    }
    if ( $mode eq 'list' ) {
        foreach my $mo ( sort @modules ) {
            chomp $mo;
            $mo =~ s{^$wt/}{}gmx;    #/home/c/g/wt/modules/zsh -> zsh
            $s->o( $s->c( 'module', "$mo " ) );
        }
        $s->o("\n");
        return;
    }
    foreach my $mo ( sort @modules ) {
        chomp $mo;
        $mo =~ s{^$wt/}{}gmx;        #/home/c/g/wt/modules/zsh -> zsh
        my $md = $mo . $dot;
        if ( $s->should_be_applied($mo) ) {
            $s->read_module($mo);
            $result->{$mo}->{considered} = 1;
        }
        else {
            $result->{$mo}->{considered} = 0;
        }

    }

    # make a query, print verbose query
    $s->v( "=" x ( 78 - $o->{indentation} ) . "\n" );
    my $unprovided_objects = $s->query_unprovided();

    # make a validation, print verbose validation
    $s->v( "=" x ( 78 - $o->{indentation} ) . "\n" )
        if $unprovided_objects;
    $s->planning($unprovided_objects) if $unprovided_objects;

    # print result
    $s->v( "=" x ( 78 - $o->{indentation} ) . "\n" );
    $s->v("Verbose results:\n");
    $s->v("  number of objects to update: $unprovided_objects\n");
    $s->v( "  number of command sections: " . $s->count_commands / 2 . "\n" );

    $s->v("\n") if $mode eq 'show';
    my $dx = $dl - 12;
    $s->v(
        sprintf( "%-$dx.${dx}s  %s %s\n", 'module', 'considered', 'status' ) )
        if $mode eq 'show';
    $s->v( "_" x ( 78 - $o->{indentation} ) . "\n" ) if $mode eq 'show';
    foreach my $mo ( sort @modules ) {
        chomp $mo;
        $mo =~ s{^$wt/}{}gmx;    #/home/c/g/wt/modules/zsh -> zsh
        my $md = $s->c( 'module', $mo ) . $dot;
        my $considered
            = ( $result->{$mo}->{considered} )
            ? $s->c( 'yes', 'YES' )
            : $s->c( 'no',  'NO ' );
        my $todo
            = ( not $result->{$mo}->{considered} ) ? $s->c( 'done', '----' )
            : ( $result->{$mo}->{todo} ) ? $s->c( 'todo', 'TODO' )
            :                              $s->c( 'done', 'DONE' );

        $s->o(
            sprintf(
                "%-$dl.${dl}s [ %s ] [ %s ]\n", $md, $considered, $todo
            )
        ) if $mode eq 'show';

    }

    $s->v( "=" x ( 78 - $o->{indentation} ) . "\n" );

    if ($unprovided_objects) {
        $s->action();    # do action if any
        if ( $mode eq 'show' ) {
            $s->v( "=" x ( 78 - $o->{indentation} ) . "\n" );
            if ( $modules eq q{} ) {
                $s->o( $s->c( 'execute', " ningyou apply all" ) );
                $s->o( ' What would be done:'
                        . $s->c( 'execute', " ningyou script all\n" ) );
            }
            else {
                $s->o( $s->c( 'execute', " ningyou apply $modules" ) );
                $s->o( ' What would be done:'
                        . $s->c( 'execute', " ningyou script $modules\n" ) );
            }
        }
    }
    else {
        $s->o( $s->c( 'ready', "Ningyou is already up-to-date\n" ) );
    }

    $s->d("END\n");
    return 1;
}

sub get_or_setup_cfg {
    my ( $s, $cfg_fn, $u ) = @_;

    my $fn = glob $cfg_fn;    # master cfg (~/.ningyou/master.ini)
    my $d  = dirname($fn);
    if ( $mode eq 'init' ) {
        die "Can not create $d, it is already there! (please remove)\n" if -d $d;
        $u->ask_to_create_directory($d);
    }

    die "please provide directory $d\n"                if not -d $d;
    die "please provide master configuration $d/$fn\n" if not -e $fn;
    $cfg        = Config::INI::Reader->read_file($fn);
    $repository = $s->get_repository( $cfg, $f->{fqdn} );
    $wt         = $s->get_worktree( $cfg, $repository );
    die "please provide working tree $wt\n" if not -d $wt;
    $provider = $cfg->{provider};

    return $cfg;
}

sub get_repository {
    my ( $s, $c, $d ) = @_;    #  c = cfg (master), d = fqdn

    my $m = "ERROR: Node [$d] not mentioned in section [nodes]\n";
    $m .= "Please add node to master.ini\n";
    my $r = exists $c->{nodes}->{$d} ? $c->{nodes}->{$d} : die $m;
    $s->d("use repository: $r\n");

    return $r;
}

sub get_worktree {
    my ( $s, $c, $r ) = @_;    # c = cfg (master), r = repository name

    my $se = 'repositories';
    my $m  = "ERROR: a repository called '$r' is\n";
    $m .= "not mentioned in section [$se]!\n";
    $m .= "Please add repository to master.ini\n";
    my $wt = exists $c->{$se}->{$r} ? $c->{$se}->{$r} : die $m;
    $s->d("use worktree: $wt\n");

    return $wt;
}

# query OBJECTs of PROVIDER if applied or not
# returns number of unprovided objects
sub query_unprovided {
    my ( $s, $i ) = @_;
    return if $mode eq 'full-show';
    return if $mode eq 'full-script';

    my $unprovided = 0;

    # foreach provider: File, Directory, ...
    $s->v("Query: what is already provided and what not ...\n");
    $s->d("Foreach entry id (provider:object)\n");
    foreach my $id ( $s->ids_cfg ) {    # id = provider:object
        my ( $pr, $iv ) = $s->id($id);
        my $provided = $s->check_provided($id);
        $unprovided++ if not $provided;
    }
    return $unprovided;
}

sub check_provided {
    my ( $s,  $id ) = @_;
    my ( $pr, $iv ) = $s->id($id);
    my $o = $s->get_options;
    $s->v(    "- Q: do provider "
            . $s->c( 'file', $pr )
            . " provide object "
            . $s->c( 'module', $iv )
            . "?\n" );
    my $msg
        = "ERROR: provider "
        . $s->c( 'file', $pr )
        . " not supported!\n"
        . "Please install the provider Ningyou::Provider::"
        . ucfirst $pr
        . "\nand consider adding it at"
        . " section [providers] in master.ini\n";
    die $msg if not exists $provider->{$pr};
    my $module = "Ningyou::Provider::" . ucfirst $pr;
    eval "use $module";
    die $@ if defined $@ and $@;
    my $p = $provider->{$pr}->new( { options => $o } );

    my $cfg
        = ( $s->is_cfg($id) and exists $s->get_cfg($id)->{module} )
        ? $s->get_cfg($id)->{module}
        : {};

    my $is_provided = $p->applied(
        {
            cfg      => $cfg,     #$r->{$pr}->{$iv},
            object   => $iv,
            provider => $pr,
            cache    => $cache,
            wt       => $wt,
            dryrun   => 1,
            itemize  => 1,
            base     => '-a',
        }
    );
    if ($is_provided) {
        $s->set_provided( "$pr:$iv" => 1 );
        $s->v(    "- A: "
                . $s->c( 'yes',    'YES' ) . ", "
                . $s->c( 'module', $iv ) . " "
                . $s->c( 'file',   $pr )
                . " allready provied\n" );
    }
    else {
        $s->set_provided( "$pr:$iv" => 0 );
        $s->v(    "- A: "
                . $s->c( 'no',     'NO' ) . ", "
                . $s->c( 'module', $iv )
                . " not provied\n" );
        $s->v(    "  Therefore "
                . $s->c( 'module', $iv )
                . " is going to be provided via ["
                . $s->c( 'file', 'apply' )
                . "]\n" );
        my $cmd = $p->apply(
            {

                # mandatory
                cache    => $cache,
                object   => $iv,
                provider => $pr,
                cfg      => $cfg,
                wt       => $wt,
            }
        );
### ###
        if ( defined $cmd ) {
            $s->v("  add cmd [$cmd]");
            my $mo = $cfg->{module};
            $s->v("  module  [$mo]");
            my $y = "=" x 78;
            my $x = sprintf( "# === module [%s] === object [%s] ===%s",
                $mo, $id, $y );
            if ( $mode eq 'apply' ) {
                $s->add_command($cmd);
            }
            else {
                $s->add_command(
                    sprintf( "%-.74s\n", $s->c( 'comment', $x ) ) );
                $s->add_command( $s->c( 'command', $cmd ) . "\n" );
            }
            $result->{$mo}->{'todo'} = 1;
        }
        else {
            $s->v("no cmd from apply\n");
            my $mo = $cfg->{module};
            $result->{$mo}->{todo} = 0;
        }
    }

    return $is_provided;
}

# TODO: this is testing the dependency chain only 1 level deep
#       and only for normal providers
#       - consider to make it "indefinite" deep
#       - consider to add provider "Module"
sub planning {
    my ( $s, $i ) = @_;
    my %queue = ();

    $s->v("Query: what dependencies need to be applied:\n");
    foreach my $id ( $s->ids_cfg ) {
        my ( $pr, $iv ) = $s->id($id);

        $s->v(    "- Q: Should object "
                . $s->c( 'module', $iv )
                . " be provided via "
                . $s->c( 'file', $pr )
                . "?\n" );
        if ( $s->get_provided($id) ) {
            $s->v(    "- A: "
                    . $s->c( 'no', 'NO' )
                    . ", should not be provided via "
                    . $s->c( 'file', $pr )
                    . "\n" );
            next;
        }
        else {
            $s->v(    "- A: "
                    . $s->c( 'yes', 'YES' )
                    . ", should be provided via "
                    . $s->c( 'file', $pr )
                    . "\n" );
            my $mo = $s->get_cfg($id)->{module}->{module};
            $s->v(    "- Q: What dependecies has "
                    . $s->c( 'module', $id )
                    . "?\n" );
            foreach my $dep_id ( $s->get_dependencies($id) ) {
                die "Invalid dependency in module [$mo], missing [:]!\n"
                    if not $dep_id =~ m{:}gmx;
                $s->v(    "- A: "
                        . $s->c( 'module', $id )
                        . " has dependency [$dep_id]\n" );
                $s->check_provided($dep_id);
            }
        }
    }
    return 0;
}

sub should_be_applied {
    my ( $s, $mo ) = @_;

    return 1 if ( exists $pkg->{$mo} );
    $pkg->{$mo} = 0;

    # if should be applied globally: [packages]
    $pkg->{$mo}++
        if ( exists $cfg->{packages}->{$mo}
        and $cfg->{packages}->{$mo} );

    # if should be applied for repository
    $pkg->{$mo}++
        if ( exists $cfg->{$repository}->{$mo}
        and $cfg->{$repository}->{$mo} );

    # if it should be applied for client
    $pkg->{$mo}++
        if exists $cfg->{ $f->{fqdn} }->{$mo}
            and $cfg->{ $f->{fqdn} }->{$mo};
    return $pkg->{$mo};
}

sub action {
    my ($s) = @_;

    my $o = $s->get_options;
    if ( $mode eq 'script' ) {
        $s->v(    "# number of modules to update: "
                . $s->count_commands / 2
                . "\n" );
        $s->o("export WT=$wt\n");
        my $z = 0;
        foreach my $cmd ( $s->all_commands ) {
            if ( not exists $o->{raw} ) {
                $cmd =~ s/^\s+//gmx;
                if ( $mode eq 'show' ) {
                    $cmd =~ s/^/# /gmx;
                }
                $cmd =~ s/$wt/\${WT}/gmx;
                $cmd =~ s/&&/&&\n/gmx;
            }
            $cmd =~ s{\n}{\n}gmx;
            $cmd =~ s{\s+\n}{\n}gmx;
            $s->o($cmd);
            $z++;
        }
        $s->o( $s->c( 'comment', "# EOS - end of script\n" ) );
    }
    if ( $mode eq 'apply' ) {
        foreach my $cmd ( $s->all_commands ) {
            next if $cmd =~ m{^#};
            $s->o("$cmd\n");
            my $nilicm = Ningyou::Cmd->new();
            my ( $out, $err, $res ) = $nilicm->cmd($cmd);
            if ($err) {
                $s->o( $s->c( 'error', $err . " " . $res ) );
            }
        }
    }
}

# queries the 'require' field and deliver all  dependencies
# require FIELD format:
# 1. require=package:zsh
# 2. require=package:zsh;file:/tmp/zsh
# 3. require=package:zsh,vim
# 4. require=package:zsh,vim;file:/tmp/zsh,/tmp/vim
sub get_dependencies {
    my ( $s,  $id ) = @_;            # id = package:zsh
    my ( $pr, $iv ) = $s->id($id);

    # split first ";" => require=package:zsh,vim  |  file=/tmp/zsh,/tmp/vim
    return () if not exists $s->get_cfg($id)->{module}->{require};

    my @dependencies = ();
    my $dep_test     = $s->get_cfg($id)->{module}->{require};
    $s->d("test dependencies: [$dep_test]");
    my @dep_test = split /;/, $dep_test;    # package:x,y;file:a/b,c/d
    $s->d("Foreach dependency test id (package:zsh, ...)\n");
    foreach my $tid (@dep_test) {           # package:zsh,vim
        $s->v("  - Test dependency id [$tid]\n");
        my ( $pr, $str ) = $s->id($tid);
        $s->v( "    id has provider " . $s->c( 'file', $pr ) . "\n" );
        my @d = ();
        if ( $str =~ m{,}gmx ) {            # if comma
            my @d = split /,/, $str;        # zsh,vim
            foreach my $iv (@d) {
                $s->v("     + add A dependency [$pr:$iv]\n");
                push @dependencies, "$pr:$iv";
            }
        }
        else {
            $s->v("    + add ONE dependency [$pr:$str]\n");
            push @dependencies, "$pr:$str";
        }
    }
    $s->v(
        sprintf( "    Return [%d] dependenc(y|ies)\n", scalar @dependencies )
    );
    return @dependencies;    # ( file:a/b, file:c/d, package:x, package:y )
}

sub read_modules {
    my ( $s, $i ) = @_;

    my @m = ();
    find( sub { push @m, "$File::Find::dir$/" if (/manifests$/); }, $wt );
    return \@m;
}

# read from $MODULE/manifests/i.ini
# add it to ONE Ningyou::Type::Module
# add it THE global configuration 'cfg'
# CRITIQUE: actually the type Ningyou::Type::Module do only describe
#           a part of a module, lets say an object.
#           returning the cfg value for a module is not possible
#           at the moment
sub read_module {
    my ( $s, $mo ) = @_;    # mo = module
    my $fn  = "$wt/$mo/manifests/i.ini";
    my $cfg = Config::INI::Reader->read_file($fn);

    # collect default values first
    my $def = {};
    foreach my $rid ( sort keys %{$cfg} ) {    # default : file
        my ( $pr, $iv ) = $s->id($rid);
        $s->d(    "pr "
                . $s->c( 'file',   $pr ) . " iv "
                . $s->c( 'module', $iv )
                . "\n" );                      # pr [default] iv [file]
        next if $pr ne 'default';
        $def->{$iv} = $cfg->{$rid};    # def->{file} = cfg->{default:file}
    }

    # collect all but default values
    foreach my $rid ( sort keys %{$cfg} ) {
        my ( $pr, $iv ) = $s->id($rid);
        next if $pr eq 'default';
        my $id = "$pr:$iv";
        $s->d("rid [$rid] -> id [$id] ($pr:$iv)\n");
        my $m = Ningyou::Type::Module->new;
        foreach my $k ( sort keys %{ $cfg->{$rid} } ) {
            $s->d("k [$k] =>[$cfg->{$rid}->{$k}]\n");
            $m->set_module( $k => $cfg->{$rid}->{$k} );    # 'owner' => 'c'
        }

        # add default values to the module
        foreach my $field ( sort keys %{ $def->{$pr} } ) {

            # module is the same (no def for module)
            next if $field eq 'module';

            # splice in default field values
            $s->d("Q: do we apply default value for field [$field]?\n");
            if ( not $m->is_module($field) ) {
                $s->d("A: YES ($def->{$pr}->{$field})\n");
                $m->set_module( $field => $def->{$pr}->{$field} );
            }
            else {
                $s->d("A: NO\n");
            }
        }
        $m->set_module( 'module' => $mo );    # remember own module name
        $s->set_cfg( $id => $m );    # add to the global configuration
    }
    return;
}

sub id {
    my ( $s, $id ) = @_;
    my ( $pr, $iv ) = split /\s*:\s*/, $id;
    return ( $pr, $iv );
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
