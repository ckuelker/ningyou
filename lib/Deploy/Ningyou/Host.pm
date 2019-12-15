# +---------------------------------------------------------------------------+
# | Deploy::Ningyou::Host                                                     |
# |                                                                           |
# | Host related routines                                                     |
# |                                                                           |
# | Version: 0.1.1 (change our $VERSION inside)                               |
# |                                                                           |
# | Changes:                                                                  |
# |                                                                           |
# | 0.1.1 2019-12-15 Christian Kuelker <c@c8i.org>                            |
# |     - VERSION not longer handled by dzil                                  |
# |                                                                           |
# | 0.1.0 2019-03-28 Christian Külker <c@c8i.org>                             |
# |     - initial release                                                     |
# |                                                                           |
# +---------------------------------------------------------------------------+
package Deploy::Ningyou::Host;

# ABSTRACT: Host related routines

use Moose::Role;
use namespace::autoclean;
use v5.10;    # to use state
with "Deploy::Ningyou::Util";

our $VERSION = '0.1.1';

has 'host_fqhn' => (
    isa     => 'Str',
    is      => 'rw',
    reader  => 'get_facter_fqhn',
    writer  => 'set_facter_fqhn',
    builder => 'init_facter_fqhn',
    lazy    => 1,
);

# /usr/bin/facter
#
# fqdn => w1.c8i.org
#
# get fqhn (fully qualified host name)
sub init_facter_fqhn {
    my ( $s, $i ) = @_;
    my $cmd = qq{/usr/bin/facter fqdn};
    $s->d("cmd [$cmd]");
    state $o = qx($cmd);
    chomp $o;
    $s->d("output o [$o]");
    $o = lc $o;
    return $o;
}

#__PACKAGE__->meta->make_immutable;
no Moose;
1;
__END__
