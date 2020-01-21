# +---------------------------------------------------------------------------+
# | Deploy::Ningyou::Env                                                      |
# |                                                                           |
# | Interface to the environment                                              |
# |                                                                           |
# | Version: 0.1.2 (change our $VERSION inside)                               |
# |                                                                           |
# | Changes:                                                                  |
# |                                                                           |
# | 0.1.2 2020-01-21 Christian Kuelker <c@c8i.org>                            |
# |     - bump Ningyou version                                                |
# |                                                                           |
# | 0.1.1 2019-12-15 Christian Kuelker <c@c8i.org>                            |
# |     - make Ningyou version explicit                                       |
# |                                                                           |
# | 0.1.0 2019-04-21 Christian Kuelker <c@c8i.org>                            |
# |     - initial release                                                     |
# |                                                                           |
# +---------------------------------------------------------------------------+
package Deploy::Ningyou::Env;

# ABSTRACT: Interface to the environment

use warnings;
use strict;
use Data::Dumper;
use Moose::Role;
use namespace::autoclean;
use Getopt::Long qw(:config gnu_getopt permute);
use Pod::Usage;

our $NINGYOU = '0.1.3'; # Ningyou version
our $VERSION = '0.1.1'; # Module version

has 'action_list' => (
    isa     => 'HashRef',
    is      => 'rw',
    reader  => 'get_action_list',
    writer  => 'set_action_list',
    default => sub { {} },
);

has 'debug' => (
    isa     => 'Bool',
    is      => 'rw',
    reader  => 'get_debug',
    writer  => '_set_debug',
    default => sub {
        my $r
            = ( defined $ENV{NINGYOU_DEBUG} and $ENV{NINGYOU_DEBUG} )
            ? 1
            : 0;
        return $r;
    }
);

has 'debug_filename' => (
    isa     => 'Str',
    is      => 'rw',
    reader  => 'get_debug_filename',
    writer  => '_set_debug_filename',
    lazy    => 1,                       #sometimes got undef
    default => sub {
        my $r
            = ( defined $ENV{NINGYOU_DEBUG} and $ENV{NINGYOU_DEBUG} )
            ? $ENV{NINGYOU_DEBUG}
            : q{};
        return $r;
    }
);

has 'env_options' => (
    is      => 'rw',
    isa     => 'HashRef',
    reader  => 'get_env_options',
    writer  => 'set_env_options',
    default => sub { {} },
    lazy    => 1,
);

has 'env_action' => (
    is      => 'rw',
    isa     => 'Str',
    reader  => 'get_env_action',
    writer  => 'set_env_action',
    default => q{},
);

has 'env_modules' => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { [] },
);
has 'env_bootstrap_repository' => (
    is      => 'rw',
    isa     => 'Str',
    reader  => 'get_env_bootstrap_repository',
    writer  => 'set_env_bootstrap_repository',
    default => q{},
);

with qw(Deploy::Ningyou::Util);

sub process_env_options {
    my ( $s, $action_hr ) = @_;

    $s->set_action_list($action_hr);
    my %opt = ();

    # FEATURE: indentation=i
    # FEATURE: configuration
    # FEATURE: quite
    # FEATURE: update
    my @ARGVC = @ARGV;
    GetOptions(
        \%opt,
        'configuration|c=s',
        'main-configuration-only',
        'help',
        'indentation=i',
        'man',
        'quite',
        'update',
        'verbose',
        'version', '<>',
        sub { my ( $i, $j ) = @_; $s->process_env_actions( $i, $j ) },
    );

    # --help
    pod2usage(1) if $opt{help};

    # --man
    pod2usage( -exitstatus => 0, -verbose => 2 ) if $opt{man};

    # --version
    if ( $opt{version} ) {
        $s->d( "=" x 80 );
        $s->d("BEGIN");
        $s->d("Ningyou invoked with --version option");
        if (defined $Deploy::Ningyou::Env::NINGYOU){
            print "Ningyou $Deploy::Ningyou::Env::NINGYOU\n";
        }else{
            print "Ningyou is not installed properly - no version available\n";
            print "See INSTALL.md\n";
        }
        $s->d("END");
        exit 0;
    }

    # --scope --mode --configuration|-c
    $opt{indentation} = 0 if not defined $opt{indentation};

    $s->set_env_options( \%opt );
    return \%opt;
}

sub process_env_actions {
    my ( $s, $i, $j ) = @_;

    $s->d("Deploy::Ningyou::Env::process_env_actions: ");

    my $ref = ref $i;

    # my $x = scalar $i->name;    # remove the object from the input
    #                                          Perl 5.14  Perld 5.20
    my $x = $ref eq 'Getopt::Long::CallBack' ? scalar $i->name : $i;

    $s->d("Deploy::Ningyou::Env::process_env_actions: [$x]");

    # apply bootstrap help list man module status script ...
    my @actions = sort keys %{ $s->get_action_list };

    #if ( $x ~~ @x ) {
    if ( grep { $_ eq $x } (@actions) ) {    # bootstrap, ...
        $s->set_env_action($x);
    }
    else {    # CONSIDER: is there a smarter way?
        my $last_action = $s->get_env_action;
        if ( $last_action eq 'bootstrap' ) {
            $s->set_env_bootstrap_repository($x);
        }
        else {
            push @{ $s->env_modules }, $x;
        }
    }
    if ( $x eq 'help' ) {
        pod2usage(1);
    }
    if ( $x eq 'man' ) {
        pod2usage( -exitstatus => 0, -verbose => 2 );
    }
    return;
}

no Moose;

1;
__END__

=pod

=head1 NAME

Deploy::Ningyou::Env

=head1 SYNOPSIS

todo

=head1 DESCRIPTION

B<This program> will read the given input file(s) and do something
useful with the contents thereof.

=cut


