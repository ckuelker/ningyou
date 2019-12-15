# +---------------------------------------------------------------------------+
# | Deploy::Ningyou::Provider::Nop                                            |
# |                                                                           |
# | Provides no (no operation) deployment                                     |
# |                                                                           |
# | Version: 0.1.1 (change our $VERSION inside)                               |
# |                                                                           |
# | Changes:                                                                  |
# |                                                                           |
# | 0.1.1 2019-12-15 Christian Kuelker <c@c8i.org>                            |
# |     - VERSION not longer handled by dzil                                  |
# |                                                                           |
# | 0.1.0 2019-03-31 Christian Kuelker <c@c8i.org>                            |
# |     - initial release                                                     |
# |                                                                           |
# +---------------------------------------------------------------------------+
package Deploy::Ningyou::Provider::Nop;

# ABSTRACT: Provides no deployment

use Data::Dumper;
use Moose;
use namespace::autoclean;

has 'cmd' => (
    isa     => 'ArrayRef',
    is      => 'rw',
    reader  => 'get_cmd',
    writer  => 'set_cmd',
    default => sub { return []; },
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
    Deploy::Ningyou::Execute
    Deploy::Ningyou::Util::Provider
);

our $VERSION = '0.1.1';

sub register { return 'nop'; }
sub parameter { return { script => 0, loc => 1, cfg => 1, sec => 1, }; }

sub parameter_description {
    return {
        script => 'script mode only prints commands',
        loc    => 'location of the configuration file',
        cfg    => 'configuration snippet of a section',
        sec    => 'section of the configuration file',
    };
}

sub parameter_default { return { dry   => 1 }; }
sub attribute         { return { debug => 1, }; }
sub attribute_default { return { debug => 0, }; }

sub attribute_description {
    return { debug => 'string printed in debug log', };
}

sub init   { return 1; }
sub script { return 0; }
sub apply  { my ( $s, $i ) = @_; return $s->standard_apply($i); }

sub applied {
    my ( $s, $i ) = @_;
    my ( $v, $sec, $cls, $prv, $dst, $cfg, $c, $loc, $ok )
        = $s->applied_in( { i => $i } );
    $s->e( 'section is not OK', 'cfg' ) if not $ok;
    my @cmd = @{ $s->get_cmd };

    # 0. indicated the beginning
    push @cmd, { verbose => 'provider [nop] BEGIN' };

    # 1. the real action or script
    foreach my $attr ( sort keys %{ $i->{cfg} } ) {
        my $cmd = qq{echo "$i->{cfg}->{$attr}"};
        push @cmd, { cmd => $cmd, verbose => "No Operation NOP for debug" };
    }

    # 2. indicate the end
    push @cmd, { verbose => 'provider [nop] END' };
    $s->set_cmd( \@cmd );
    return 0;
}

__PACKAGE__->meta->make_immutable;

1;
__END__

