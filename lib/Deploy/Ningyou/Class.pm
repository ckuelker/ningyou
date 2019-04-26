# +---------------------------------------------------------------------------+
# | Deploy::Ningyou::Class                                                    |
# |                                                                           |
# | Class definitions                                                         |
# |                                                                           |
# | Version: 0.1.0 (change our $version inside)                               |
# |                                                                           |
# | Changes:                                                                  |
# |                                                                           |
# | 0.1.0 2019-04-04 Christian Külker <c@c8i.org>                             |
# |     - initial release                                                     |
# |                                                                           |
# +---------------------------------------------------------------------------+
package Deploy::Ningyou::Class;

# ABSTRACT: Class definitions

use Moose;
use namespace::autoclean;

our $version = '0.1.0';

has 'ini' => (
    isa      => 'Config::Tiny',
    is       => 'rw',
    reader   => 'get_ini',
    writer   => '_set_ini',
    required => 1,
);

has 'classes' => (
    isa     => 'ArrayRef',
    is      => 'rw',
    reader  => 'get_classes',
    writer  => 'set_classes',
    lazy    => 1,
    default => sub {
        my ( $s, $i ) = @_;
        my $ini  = $s->get_ini;
        my $fqhn = $s->get_fqhn( { ini => $ini } );
        my $dist = $s->get_distribution( { ini => $ini } );
        return [ 'global', $dist, $fqhn ];
    },
);

with qw(Deploy::Ningyou::Util);

__PACKAGE__->meta->make_immutable;

1;
__END__
