# +---------------------------------------------------------------------------+
# | Deploy::Ningyou::Dependency                                               |
# |                                                                           |
# | Calculate dependencies for status, apply and script                       |
# |                                                                           |
# | Version: 0.1.0 (change our $version inside)                               |
# |                                                                           |
# | Changes:                                                                  |
# |                                                                           |
# | 0.1.0 2019-03-04 Christian Külker <c@c8i.org>                             |
# |     - initial release                                                     |
# |                                                                           |
# +---------------------------------------------------------------------------+
# ENTRY A: ::Aplly ::Script
#   1 init->add_sections_to_vertices
#   2 init->add_required_to_edges
# ENTRY B: ::Status
#   1 is_module_applied->add_sections_to_vertices
#   2 is_module_applied->add_required_to_edges
package Deploy::Ningyou::Dependency;

# ABSTRACT: Calculate dependencies for status, apply and script

use Data::Dumper;
use Graph::Directed;
use Moose;
use namespace::autoclean;
use Deploy::Ningyou::Class;
use Test::Deep::NoTest qw(eq_deeply);

our $version = '0.1.0';

has 'ini' => (
    isa      => 'Config::Tiny',
    is       => 'rw',
    reader   => 'get_ini',
    writer   => 'set_ini',
    required => 1,
    default  => sub { },
);
has 'opt' => (
    isa      => 'HashRef',
    is       => 'rw',
    reader   => 'get_opt',
    writer   => 'set_opt',
    required => 1,
    default  => sub { },
);

#       p,v,d,e       get_fqhn      get_worktree
with qw(Deploy::Ningyou::Util Deploy::Ningyou::Cfg);

# ini is 1 Config::Tiny Perl Class that has  Config::Tiny included as 'host'
#
# bless( {
#   'global' => { 'worktree' => '/tmp/ningyou' },
#   'host' => bless( {
#     'debian-gnu-linux-9.8-stretch-amd64-x86_64' => { 'default' => '1' },
#     'w1.c8i.org' => { 'default' => '3' },
#     'version' => {
#       'configuration' => '0.1.0',
#       'file' => '0.1.0',
#       'project' => '0.1.0'
#     },
#     'global' => {
#       'vim' => '1',
#       'default' => '1',
#       'zsh' => '1'
#     }
#   }, 'Config::Tiny' ),
#   'version' => {
#     'file' => '0.1.0',
#     'project' => '0.1.0',
#     'configuration' => '0.1.0'
#   }
# }, 'Config::Tiny' );
#
#
# Graph.pm terminology
#   vertex   = node                $g->add_vertex($v)
#   edge     = conection           $g->add_edge($v,$w)
#   sink     = leaf                $g->is_sink_vertex($v)     @v = $g->sink_vertices()
#   source   = root                $g->is_source_vertex($v)   @v = $g->source_vertices()
#   isolated = not connected       $g->is_isolated_vertex($v) @v = $g->isolated_vertices()
#   exterior = not connected?      $g->is_exterior_vertex($v) @v = $g->exterior_vertices()
#
# is_module_applied - used by Deploy::Ningyou::Action::Status
#
# IN:
#     class:  STR          - global
#     module: STR          - backup
#     ini:    Config::Tiny - ~/.ningyou.ini
#     opt:    HASH         - { verbose => 1 }
#     meta:   HASH         - { sec => { fn => '', ...} }
#
# OUT:
#    is_module_applied: BOOL - 0|1
#    meta:              HASH - { sec => { fn => '', ...} }
sub is_module_applied {
    my ( $s, $i ) = @_;
    my $mandatory
        = { class => 1, module => 1, ini => 1, opt => 1, meta => 1 };
    $i = $s->validate_parameter( $mandatory, $i, {} );
    my $verbose = $s->get_verbose($i);

    # add full sections as vertices to the graph
    my ( $g, $r, $p, $n ) = undef;
    ( $g, $r, $i->{meta}, $p, $n ) = $s->add_sections_to_vertices(
        {
            opt    => $i->{opt},
            ini    => $i->{ini},
            class  => $i->{class},
            module => $i->{module},
            r      => {},             # config snippet
            meta   => $i->{meta},
        }
    );

    # add dependencies to graph (require attribute)
    ( $g, my $required_by )
        = $s->add_required_to_edges(
        { g => $g, r => $r, meta => $i->{meta} } );

    $s->d("graph $g");
    my $exe = $s->get_providers;
    my @sec = sort $g->vertices;

    my $fmodule = "$i->{class}:$i->{module}";
    my $return  = 1;
    foreach my $sec ( sort @sec ) {
        my ( $class, $provider, $destination ) = $s->parse_section($sec);
        $s->d("sec [$sec] c[$class] p[$provider] d[$destination]");
        my $rmodule
            = exists $required_by->{$sec}
            ? $required_by->{$sec}
            : $fmodule;
        my $fn = $s->module_to_ini( { class => $class, module => $rmodule } );
        my $applied
            = exists $exe->{$provider}->{applied}
            ? $exe->{$provider}->{applied}
            : $s->e(
            "Unknown provider [$provider] applied\n"
                . "at section [$sec]\nin [$fn]",
            'cfg'
            );
        my $o = {    # options
            cfg => $r->{$sec},
            loc => $fn,          # filename of cfg
            sec => $sec,         # full section
            opt => $i->{opt},
            dry => 0,
        };
        if ( $applied->($o) ) {
            $s->p( sprintf "  - %-69s [%s]\n", $sec, $s->c( 'yes', 'DONE' ) )
                if $verbose;
        }
        else {
            $s->p( sprintf "  - %-69s [%s]\n", $sec, $s->c( 'no', 'TODO' ) )
                if $verbose;
            $return = 0;
        }
    }
    return ( $return, $i->{meta} );
}

# IN:
#     class:  class name: global, HOSTNAME, DISTRIBUTION
#     module: vim, ...
#     g:      graph
#     r:      configuration snippet
#     meta:   meta data
# OUT:
#     g:    graph                  - with added vertices
#     r:    configuration snippet  - with section config
#     meta: meta data              - with section meta data
#     n:    vertices count
sub add_sections_to_vertices {
    my ( $s, $i ) = @_;
    my $mandatory
        = { class => 1, module => 1, ini => 1, meta => 1, r => 1, opt => 1 };
    $i = $s->validate_parameter( $mandatory, $i, {} );

    my $verbose = $s->get_verbose($i);
    my $g = exists $i->{g} ? $i->{g} : Graph::Directed->new();

    # 0. vars

    # 1. calculate file name
    my $fn = $s->module_to_ini(
        { class => $i->{class}, module => $i->{module} } );
    $s->e( "no file [$fn]", 'cfg' ) if not -f $fn;
    $s->d(
        "module [$i->{module}] full module [$i->{class}:$i->{module}] => [$fn]\n"
    );

    # 2. read module ini with template evaluation
    my $mcfg = $s->read_template_ini( { fn => $fn, ini => $i->{ini} } );

    # 3. interate through all sections $sec, make them full sections $fsec
    my $n = 0;
    foreach my $sec ( sort keys %{$mcfg} ) {

        # 4. construct full section
        my $fsec = "$i->{class}:$sec";
        $s->d("got full section  [$fsec]\n");

        # 5. check config section snippet
        if ( exists $i->{r}->{$fsec} ) {
            my $fsec_c = $s->c( 'section', $fsec );
            my $sec_c  = $s->c( 'section', $sec );
            my $fnc    = $s->c( 'file',    $fn );
            my $location = "[$fsec_c] as [$sec_c]\nat [$fnc]";
            if ( eq_deeply( $i->{r}->{$fsec}, $mcfg->{$sec} ) ) {
                my $msg = "found duplicate with same definition\n$location";
                $s->w($msg);
            }
            else {
                $s->e( "found duplicate $location", 'dublicate' );
            }
        }
        else {
            $i->{r}->{$fsec} = $mcfg->{$sec};
        }

        # 6. collect some data
        $i->{r}->{$fsec}    = $mcfg->{$sec};
        $i->{meta}->{$fsec} = {
            fn     => $fn,             # .../manifests/vim.ini
            class  => $i->{class},     # global
            module => $i->{module},    # vim (vim.ini)
            ssec   => $sec,            # short section
            fsec   => $fsec,           # full section
            sec    => $fsec            # normalized section (full section)
        };

        # 7. add vertex
        $g->add_vertex($fsec);         # add full vertex
        $n++;
    }

    # OUT
    # g: graph
    # r:
    # m:
    # n
    return ( $g, $i->{r}, $i->{meta}, $n );
}

# iterate through configuration ($r) and
# - check require field: warn if a require do not point to a full section
# - collect all requires ($required_by)
# IN:
#     g:     graph
#     r:    configuration snippets or full sections
#     meta: meta info
# OUT:
#     g: graph
#     required-by: collectd require
#     meta: meta info
sub add_required_to_edges {
    my ( $s, $i ) = @_;
    my $mandatory = { g => 1, r => 1, meta => 1 };
    $i = $s->validate_parameter( $mandatory, $i, {} );
    my $g = $i->{g};
    my $r = $i->{r};

    # collect graph edges:
    # - check full sections
    # - print warning if guess is needed
    # - add edge
    my $required_by = {};

    # iterate full sections: global:package:vim, global:file:/root/.zshrc, ...
    foreach my $sec ( sort keys %{$r} ) {
        $s->d("process full section [$sec]");
        if ( exists $r->{$sec}->{require} ) {

            # list of sections to be required (order could matter)
            my @requires = split /\s*,\s*/, $r->{$sec}->{require};
            foreach my $req0 (@requires) {    # no sort, order could matter
                my $req1 = $s->section_to_full_section(
                    { sec => $sec, req => $req0 } );
                $required_by->{$req1} = $sec;
                my $w0 = "changed [require=$req0] to [require=$req1]";
                my $w1 = "Consider updating the configuration [$sec]?";
                $s->w("$w0\n$w1") if $req0 ne $req1;

                my $loc
                    = (     exists $i->{meta}
                        and exists $i->{meta}->{$sec}
                        and defined $i->{meta}->{$sec}
                        and exists $i->{meta}->{$sec}->{fn}
                        and defined $i->{meta}->{$sec}->{fn} )
                    ? $i->{meta}->{$sec}->{fn}
                    : 'unknown';

                $s->e(
                    "Self reference in configuration:\n[$req1] "
                        . $s->c( 'no', '=' )
                        . " [$sec]\nin section [$sec]"
                        . "\nat [$loc]",
                    'selfref'
                ) if $req1 eq $sec;
                $g->add_edge( $req1, $sec );    # add full edge
                $s->d("add edge $req1 -> $sec");
            }
        }
    }
    return ( $g, $required_by, $i->{meta} );
}

sub init {   # used by Deploy::Ningyou::Action::Apply (indirect also ::Script)
    my ( $s, $i ) = @_;
    my $opt          = $s->get_opt;
    my $ini          = $s->get_ini;
    my $distribution = $s->get_distribution( { ini => $ini } );
    my $fqhn         = $s->get_fqhn( { ini => $ini } );
    my $nc           = Deploy::Ningyou::Class->new( { ini => $ini } );
    my $classes      = $nc->get_classes;
    my $g            = Graph::Directed->new();

    # read configuration space:
    # - collect full sections and its origin in $provided
    # - collect graph vertexes in               $g
    # - collect configuration in                $r
    # - collect meta info     in                $meta
    my $r    = {};    # return configuration per section
    my $meta = {};    # return meta information per section
    foreach my $c ( sort @{$classes} ) {    # global, ...
        $s->d("class [$c]\n");
        my $class_cfg
            = exists $ini->{host}->{$c}
            ? $ini->{host}->{$c}
            : $s->e( "section [$c] missing from [$fqhn.ini]", 'cfg' );
        foreach my $cc ( sort keys %{$class_cfg} ) {    # vim, zsh, ...

            # skip not enabled modules
            if ( $class_cfg->{$cc} ) {
                $s->d("module [$cc] is enabled\n");
            }
            else {
                $s->d("module [$cc] is disabled\n");
                next;
            }

            # add full sections as vertices to the graph
            ( $g, $r, $meta, my $n ) = $s->add_sections_to_vertices(
                {
                    opt    => $opt,
                    ini    => $ini,
                    class  => $c,
                    module => $cc,
                    meta   => $meta,
                    r      => $r,
                    g      => $g,
                }
            );
        }
    }

    # add dependencies to graph (require attribute)
    ( $g, my $required_by )
        = $s->add_required_to_edges( { g => $g, r => $r, meta => $meta } );

    # graph
    if   ( $g->is_dag ) { $s->d("graph is a DAG\n"); }
    else                { $s->e("graph is not a DAG\n[$g]"); }
    $s->d("graph: [$g]");

    # create queue from graph
    # see doc/task-queue-from-dependency-tree for more info
    my @stack = sort $g->vertices();
    my @queue = ();
    my %ok    = ();
    my $n     = 0;
    while ( scalar @stack ) {
        $n++;
        my $stack0 = join q{|}, @stack;

        # with [1] shift [2] push    ([1] remove first [2] add last)
        # -> minimal iterations due to order of @stack
        # with [1] pop   [2] unshift ([1] remove last  [2] add first)
        my $v = pop @stack;    # [1] remove from end

        # bootstrap @queue: source(root) and isolated vertex
        # dependency is always OK;
        my $source = $g->is_source_vertex($v)   ? 1 : 0;
        my $iso    = $g->is_isolated_vertex($v) ? 1 : 0;
        if ($source) {
            push @queue, $v;
            $ok{$v} = 1;
            $s->d( sprintf "%-25s =>", "+ $v is source (root)" );
        }
        elsif ($iso) {
            push @queue, $v;
            $ok{$v} = 1;
            $s->d( sprintf "%-25s =>", "+ $v is isolated" );
        }
        else {
            my @d  = $g->predecessors($v);    # down nodes
            my $dc = scalar @d;               # down nodes counter
            foreach my $d ( sort @d ) {       # all down nodes: A (for C or D)
                if ( defined $ok{$d} and $ok{$d} ) {   # dependency met for $v
                    push @queue, $v;                   # add to queue
                    $ok{$v} = 1;                       # mark as dependency OK
                    $s->d( sprintf "%-15s =>", "+ $v dependency met     " );
                }
                else {                                 # dependency NOT met v
                    unshift @stack, $v;    # [2] add to top of stack
                    $ok{$v} = 0;           # mark as dependency NG
                    $s->d( sprintf "%-15s =>", "+ $v dependency NOT met " );
                }
            }
        }
        my $queue  = join q{>}, @queue;
        my $stack1 = join q{|}, @stack;
        $stack0 =~ s{(\]|\[)}{}gmx;
        $stack1 =~ s{(\]|\[)}{}gmx;
        $queue =~ s{(\]|\[)}{}gmx;
        my $f = " %02d %s root[%s] leaf[%s] s0:%-18s s1:%-18s queue:%-18s\n";
        my @print = ( $n, $v, $source, $iso, $stack0, $stack1, $queue );
        $s->d( sprintf $f, @print );
    }
    return ( \@queue, $r, $meta );
}

__PACKAGE__->meta->make_immutable;
1;
__END__

