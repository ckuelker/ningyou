package Ningyou::Options;
use utf8;                        # so literals and identifiers can be in UTF-8
use v5.12;                       # or later to get "unicode_strings" feature
use strict;                      # quote strings, declare variables
use warnings;                    # on by default
use warnings qw(FATAL utf8);     # make encoding glitches fatal
use open qw(:std :utf8);         # undeclared streams in UTF-8
use charnames qw(:full :short);  # unneeded in v5.16
use Encode qw(decode_utf8);
use Pod::Usage;
use Moose;
use Getopt::Long qw(:config gnu_getopt permute);
use namespace::autoclean;
our $VERSION = '0.0.9';

has 'options' => (
    is      => 'rw',
    isa     => 'HashRef',
    reader  => 'get_options',
    writer  => 'set_options',
    default => sub { {} },
    lazy    => 1,
);
has 'command' => (
    is      => 'rw',
    isa     => 'Str',
    reader  => 'get_command',
    writer  => 'set_command',
    default => q{},
);
has 'modules' => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub { [] },
);

sub process_options {
    my ( $s, $i ) = @_;
    my %opt = ();

    GetOptions(
        \%opt,           'configuration|c=s',
        'debug:s',       'help',
        'indentation=s', 'init',
        'man',
        'module=s', 'quite',
        'raw',      'script',
        'update',   'verbose',
        'version',  '<>',
        sub { my ( $i, $j ) = @_; $s->process_commands( $i, $j ) },
    );

    # --help
    pod2usage(1) if $opt{help};

    # --man
    pod2usage( -exitstatus => 0, -verbose => 2 ) if $opt{man};

    # --version
    if ( $opt{version} ) {
        print "Ningyou $VERSION\n";
        exit 0;
    }

    # --scope --mode --configuration|-c
    $opt{indentation} = 0 if not defined $opt{indentation};

    $s->set_options( \%opt );
    return \%opt;
}

sub process_commands {
    my ( $s, $i, $j ) = @_;

    #my $x = scalar $i->name;    # remove the object from the input
    my $x = scalar $i;
    my @x = qw(help show script apply list init);

    #if ( $x ~~ @x ) {
    if ( grep { $_ eq $x } @x ) {
        print "SET\n";
        $s->set_command($x);
    }
    else {
        print "PUSH\n";
        push @{ $s->modules }, $x;
    }
    if ( $x eq 'help' ) {
        pod2usage(1);
    }
    return;
}

1;
__END__

=pod

=head1 NAME

Ningyou::Options -  Ningyou Command-Line User Interface

=cut
