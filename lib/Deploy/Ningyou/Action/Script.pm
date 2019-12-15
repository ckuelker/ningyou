# +---------------------------------------------------------------------------+
# | Deploy::Ningyou::Action::Scripts                                          |
# |                                                                           |
# | Provides script argument action                                           |
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
package Deploy::Ningyou::Action::Script;

# ABSTRACT: Provides script argument action

use strict;
use warnings;
use Config::INI::Reader;
use Data::Dumper;
use Moose;
use namespace::autoclean;
use Deploy::Ningyou::Action::Apply;

# mandatory attribute for constructor
has 'ini' => (
    isa    => 'Config::Tiny',
    is     => 'ro',
    reader => 'get_ini',
    writer => '_set_ini',

    #required=> 1, # do not seem to work with Module::Pluggable
);

with qw(
    Deploy::Ningyou::Util
    Deploy::Ningyou::Util::Action
    Deploy::Ningyou::Modules
);

our $VERSION = '0.1.1';

sub register              { return 'script'; }
sub parameter             { return { module => 0 }; }
sub parameter_description { return { module => 'name of module' }; }
sub attribute             { return {}; }
sub attribute_description { return {}; }
sub init                  { return 1; }

sub apply {
    my ( $s, $i ) = @_;
    $i = $s->validate_parameter( { ini => 1, mod => 1, opt => 1 }, $i, {} );
    my $action = $s->register;

    # 1. get a Deploy::Ningyou::Action::Script;
    my $na = Deploy::Ningyou::Action::Apply->new( { ini => $i->{ini} } );

    # 2. add the print and no-execute option dry=1
    $i->{dry} = 1;

    # 3. apply the script
    my ( $r, $script ) = $na->apply($i);
    foreach my $line ( @{$script} ) {
        next if not defined $line;
        next if not $line;
        chomp $line;
        $s->p("$line\n");
    }
    return $r;
}

sub applied { return 1; }

__PACKAGE__->meta->make_immutable;

1;

__END__

