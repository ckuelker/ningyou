# +---------------------------------------------------------------------------+
# | Deploy::Ningyou::Provider                                                 |
# |                                                                           |
# | Provider plugin aggregator                                                |
# |                                                                           |
# | Version: 0.1.1 (change our $VERSION inside)                               |
# |                                                                           |
# | Changes:                                                                  |
# |                                                                           |
# | 0.1.1 2019-12-15 Christian Kuelker <c@c8i.org>                            |
# |     - make API version explicit                                           |
# |                                                                           |
# | 0.1.0 2019-04-26 Christian Kuelker <c@c8i.org>                            |
# |     - initial release                                                     |
# |                                                                           |
# +---------------------------------------------------------------------------+
package Deploy::Ningyou::Provider;

# ABSTRACT: Provider plugin aggregator

use Moose;
use Module::Pluggable
    search_path => ['Deploy::Ningyou::Provider'],
    require     => 1,
    instantiate => 'new';

with qw(Deploy::Ningyou::Util);

our $API     = '0.1.0';    # Provider API version
our $VERSION = '0.1.0';

sub get_plugins {
    my ( $s, $i ) = @_;
    my $myself = 'Deploy::Ningyou::Provider::begin';
    $s->d( "$myself VERSION $Deploy::Ningyou::Provider::VERSION");
    $s->d( "$myself API $Deploy::Ningyou::Provider::API");
    my $r       = {};
    my @plugins = $s->plugins;
    foreach my $class ( sort @plugins ) {
        $s->d("found plugin class [$class]");
        my $cmd = $class->register();
        $r->{$cmd} = {
            plugin_version        => $Deploy::Ningyou::Provider::API,
            init                  => sub { $class->init(@_) },
            apply                 => sub { $class->apply(@_) },
            applied               => sub { $class->applied(@_) },
            script                => sub { $class->script(@_) },
            class                 => $class,
            command               => $cmd,
            parameter             => $class->parameter,
            parameter_description => $class->parameter_description,
            attribute             => $class->attribute,
            attribute_description => $class->attribute_description,
        };
        $s->d("register action [$cmd]");
    }
    return $r;
}
no Moose;
1;
__END__
