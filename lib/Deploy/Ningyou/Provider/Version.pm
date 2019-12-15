# +---------------------------------------------------------------------------+
# | Deploy::Ningyou::Provider::Version                                        |
# |                                                                           |
# | Provides versions                                                         |
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
package Deploy::Ningyou::Provider::Version;

# ABSTRACT: Provides versions

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

sub register { return 'version'; }

sub parameter {
    return { loc => 1, cfg => 1, sec => 1, opt => 1, dry => 0, };
}

sub parameter_description {
    return {
        loc => 'location of the configuration file',
        cfg => 'configuration snippet of a section',
        sec => 'section of the configuration file',
        opt => 'commandline options',
        dry => 'dry run for ::Script',
    };
}

sub parameter_default { return { dry => 1 }; }
sub attribute { return { project => 1, configuration => 1, file => 1, }; }

sub attribute_default {
    return { project => 0, configuration => 0, file => 0, };
}

sub attribute_description {
    my $vn = 'version number - handled by';
    return {
        project       => "ningyou project $vn Deploy::Ningyou",
        configuration => "configuration space $vn Deploy::Ningyou",
        file          => "configuraton file $vn the system administrator",
    };
}    # param => description

sub init   { return 1; }
sub script { return 1; }    #enables output in script
sub apply { my ( $s, $i ) = @_; return $s->standard_apply($i); }

sub applied {
    my ( $s, $i ) = @_;
    my ( $v, $sec, $cls, $prv, $dst, $cfg, $c, $loc, $ok )
        = $s->applied_in( { i => $i } );
    $s->e( 'section is not OK', 'cfg' ) if not $ok;
    my @cmd = @{ $s->get_cmd };
    $s->set_cmd( \@cmd );
    return 1;
}
__PACKAGE__->meta->make_immutable;

1;
__END__

