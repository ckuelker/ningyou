# +---------------------------------------------------------------------------+
# | Deploy::Ningyou::Class                                                    |
# |                                                                           |
# | Class definitions                                                         |
# |                                                                           |
# | Version: 0.1.1 (change our $VERSION inside)                               |
# |                                                                           |
# | Changes:                                                                  |
# |                                                                           |
# | 0.1.1 2019-12-15 Christian Kuelker <c@c8i.org>                            |
# |     - VERSION not longer handled by dzil                                  |
# |                                                                           |
# | 0.1.0 2019-04-04 Christian Külker <c@c8i.org>                             |
# |     - initial release                                                     |
# |                                                                           |
# +---------------------------------------------------------------------------+
package Deploy::Ningyou::Class;

# ABSTRACT: Class definitions

use Moose;
use namespace::autoclean;

our $VERSION = '0.1.1';

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
        my $class = [ 'global' ];
        push @{$class}, $s->get_fqhn( { ini => $ini } );
        push @{$class}, $s->get_distribution( { ini => $ini } );
        push @{$class}, $s->get_class( { ini => $ini });
        # TODO: remove classes which are double (example [global] and [class]global=1)
        return $class;
    },
);

with qw(Deploy::Ningyou::Util);

__PACKAGE__->meta->make_immutable;

1;
__END__
