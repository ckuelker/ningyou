# +---------------------------------------------------------------------------+
# | Deploy::Ningyou::Action                                                   |
# |                                                                           |
# | Action plugin aggregator (arguements from command line)                   |
# |                                                                           |
# | Version: 0.1.1 (change our $VERSION inside)                               |
# |                                                                           |
# | Changes:                                                                  |
# |                                                                           |
# | 0.1.1 2019-12-15 Christian Kuelker <c@c8i.org>                            |
# |     - VERSION not longer handled by dzil                                  |
# |                                                                           |
# | 0.1.0 2019-04-26 Christian Kuelker <c@c8i.org>                            |
# |     - initial release                                                     |
# |                                                                           |
# +---------------------------------------------------------------------------+
package Deploy::Ningyou::Action;

# ABSTRACT: Action plugin aggregator (arguements from command line)

use Moose;
use Module::Pluggable
    search_path => ['Deploy::Ningyou::Action'],
    require     => 1,
    instantiate => 'new';

has 'ini' => (
    isa      => 'Config::Tiny',
    is       => 'ro',
    reader   => 'get_ini',
    writer   => '_set_ini',
    required => 1,
);

with qw(Deploy::Ningyou::Util);

our $VERSION = '0.1.1';

sub get_plugins {
    my ( $s, $i ) = @_;
    $s->d("Deploy::Ningyou::Action::begin $VERSION");
    my $r = {};
    my @plugins = $s->plugins( ini => $s->get_ini );
    foreach my $class ( sort @plugins ) {
        $s->d("found plugin class [$class]");
        my $cmd = $class->register();
        $r->{$cmd} = {
            plugin_version        => $Deploy::Ningyou::Action::VERSION,
            init                  => sub { $class->init(@_) },
            apply                 => sub { $class->apply(@_) },
            applied               => sub { $class->applied(@_) },
            class                 => $class,
            command               => $cmd,
            parameter             => $class->parameter,
            attribute             => $class->attribute,
            parameter_description => $class->parameter_description,
            attribute_description => $class->attribute_description,
        };
        $s->d("register action [$cmd]");
    }
    return $r;
}

__PACKAGE__->meta->make_immutable;

1;
__END__
