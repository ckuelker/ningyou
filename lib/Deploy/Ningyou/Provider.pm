# +---------------------------------------------------------------------------+
# | Deploy::Ningyou::Provider                                                 |
# |                                                                           |
# | Provider plugin aggregator                                                |
# |                                                                           |
# | Version: 0.1.0 (change our $version inside)                               |
# |                                                                           |
# | Changes:                                                                  |
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

our $version = '0.1.0';

sub get_plugins {
    my ( $s, $i ) = @_;
    $s->d(
        "Deploy::Ningyou::Provider::begin $Deploy::Ningyou::Provider::VERSION"
    );
    my $r       = {};
    my @plugins = $s->plugins;
    foreach my $class ( sort @plugins ) {
        $s->d("found plugin class [$class]");
        my $cmd = $class->register();
        $r->{$cmd} = {
            plugin_version        => $Deploy::Ningyou::Provider::VERSION,
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
