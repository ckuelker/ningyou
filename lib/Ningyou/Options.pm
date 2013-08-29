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
use Getopt::Long;
use namespace::autoclean;
our $VERSION = '0.0.2';

has 'options' => (
    is      => 'rw',
    isa     => 'HashRef',
    reader  => 'get_options',
    writer  => 'set_options',
    builder => 'process_options',
    lazy    => 1,
);

sub process_options {
    my ( $s, $i ) = @_;
    my %opt = ();

    $opt{mode}
        = $ARGV[0] eq 'show'        ? 'show'
        : $ARGV[0] eq 'full-show'   ? 'full-show'
        : $ARGV[0] eq 'script'      ? 'script'
        : $ARGV[0] eq 'full-script' ? 'full-script'
        : $ARGV[0] eq 'install'     ? 'install'
        : $ARGV[0] eq 'production'  ? 'production'
        :                             'show';

    $opt{module}
        = ( not defined $ARGV[1] ) ? 'all'
        : ( defined $ARGV[1] and $ARGV[1] eq 'all' ) ? 'all'
        : defined $ARGV[1] ? $ARGV[1]
        :                    'all';

    GetOptions(
        \%opt,        'configuration|c=s',
        'debug:s',    'help',
        'identation', 'man',
        'module=s',   'quite',
        ,             'raw',
        'script',     'update',
        'verbose',    'version',
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
    $opt{identation} = 4 if not defined $opt{identation};
    $s->set_options( \%opt );
    return $s->get_options;
}

1;
__END__

=pod

=head1 NAME

Ningyou::Options -  Ningyou Command-Line User Interface

=cut
