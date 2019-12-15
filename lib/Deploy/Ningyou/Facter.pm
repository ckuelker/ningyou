# +---------------------------------------------------------------------------+
# | Deploy::Ningyou::Facter                                                   |
# |                                                                           |
# | Collect information from the system with facter                           |
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
package Deploy::Ningyou::Facter;

# ABSTRACT: Collect information from the system with facter

use Moose;
use namespace::autoclean;
use v5.10;    # for state

with "Deploy::Ningyou::Util";

our $VERSION = '0.1.1';

has 'facter_distribution' => (
    isa     => 'Str',
    is      => 'rw',
    reader  => 'get_facter_distribution',
    writer  => 'set_facter_distribution',
    builder => 'init_facter_distribution',
    lazy    => 1,
);

# /usr/bin/facter
#
# architecture => amd64
# domain => c8i.org
# fqdn => w1.c8i.org
# hardwaremodel => x86_64
# kernel => Linux
# kernelmajversion => 4.9
# kernelrelease => 4.9.0-8-amd64
# kernelversion => 4.9.0
# lsbdistcodename => stretch
# lsbdistdescription => Debian GNU/Linux 9.8 (stretch)
# lsbdistid => Debian
# lsbdistrelease => 9.8
# lsbmajdistrelease => 9
# lsbminordistrelease => 8
# operatingsystem => Debian
# operatingsystemmajrelease => 9
# operatingsystemrelease => 9.8
# os => {"name"=>"Debian", "family"=>"Debian", "release"=>{"major"=>"9", "minor"=>"8", "full"=>"9.8"}, "lsb"=>{"distcodename"=>"stretch", "distid"=>"Debian", "distdescription"=>"Debian GNU/Linux 9.8 (stretch)", "distrelease"=>"9.8", "majdistrelease"=>"9", "minordistrelease"=>"8"}}
# osfamily => Debian

sub init_facter_distribution {
    my ( $s, $i ) = @_;

    # lsbdistdescription => Debian GNU/Linux 9.8 (stretch)
    # architecture => amd6
    # hardwaremodel => x86_6

    my @keys = qw(lsbdistdescription architecture hardwaremodel);
    my @d    = ();
    my $n    = 1;
    foreach my $key (@keys) {    # no sort
        $n++;
        my $cmd = qq{/usr/bin/facter $key};
        $s->d("cmd [$cmd]");
        my $o = qx($cmd);
        chomp $o;
        $s->d("output o [$o]");
        $o = lc $o;
        $o =~ s{\(|\)}{}gmx;
        $o =~ s{/}{-}gmx;
        $o =~ s{\s+}{-}gmx;
        push @d, $o;
    }

    # debian-gnu-linux-9.8-stretch-amd64-x86_64
    state $distribution = join q{-}, @d;
    return $distribution;
}

__PACKAGE__->meta->make_immutable;

1;
__END__
