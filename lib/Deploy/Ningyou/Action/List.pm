# +---------------------------------------------------------------------------+
# | Deploy::Ningyou::Action::List                                             |
# |                                                                           |
# | Provides list argument action                                             |
# |                                                                           |
# | Version: 0.1.0 (change our $version inside)                               |
# |                                                                           |
# | Changes:                                                                  |
# |                                                                           |
# | 0.1.0 2019-03-28 Christian Kuelker <c@c8i.org>                            |
# |     - initial release                                                     |
# |                                                                           |
# +---------------------------------------------------------------------------+
package Deploy::Ningyou::Action::List;

# ABSTRACT: Provides list argument action

use Data::Dumper;
use Moose;
use namespace::autoclean;

# mandatory attribute for constructor
has 'ini' => (
    isa    => 'Config::Tiny',
    is     => 'ro',
    reader => 'get_ini',
    writer => '_set_ini',

    #required=> 1, # do not seem to work with Module::Pluggable
);

with
    qw(Deploy::Ningyou::Util Deploy::Ningyou::Util::Action Deploy::Ningyou::Modules);

our $version = '0.1.0';

# === [ main ] ================================================================
sub register { return 'list'; }

# subroutine input options
sub parameter {
    return { ini => 1, mod => 1, opt => 1, dry => 0, };
}

sub parameter_description {
    return {
        ini => 'configuration',
        mod => 'name of module',
        opt => 'enviroment options',
        dry =>
            'flag to execute or print script: Deploy::Ningyou::Action::List',
    };
}
sub parameter_default { return { dry => 1 }; }

# configuration input options
# attribute: param => 0|1
# atribute_description: param => description
sub attribute             { return {}; }
sub attribute_description { return {}; }

sub init { return 1; }

# IN:
#   mod: [ 'global:youtube-dl' ]
#   ini:     { ... }, Config::Tiny
#   opt:     { verbose => 1 }
#   dry:    1|0
#   module: []                     - reduce list to those modules
# OUT
#   1|0
sub apply {
    my ( $s, $i ) = @_;
    $i = $s->validate_parameter( $s->parameter, $i, $s->parameter_default );
    my $verbose = $s->get_verbose($i);

    my $action  = $s->register;
    my $fqhn    = $s->get_fqhn( { ini => $i->{ini} } );
    my $wt      = $s->get_worktree;
    my $nc      = Deploy::Ningyou::Class->new( { ini => $i->{ini} } );
    my $classes = $nc->get_classes;
    my $scope   = $s->parse_scope( $i->{mod} );

    $s->d("wt [$wt]");

    my $version = $s->get_project_version;
    my $cfg_fn  = "$wt/$fqhn.ini";
    my $nstr    = "# Ningyou %s for %s with %s\n";
    my $v       = $s->c( 'version', "v$version" );
    my $h       = $s->c( 'host', $fqhn );
    my $f       = $s->c( 'file', $cfg_fn );
    $s->p( sprintf( $nstr, $v, $h, $f ) );
    my $mstr = "# %s enabled modules(s) %s in %s\n";
    my $a    = $s->c( 'action', ucfirst($action) );
    my $sc   = $s->c( 'scope', $scope );
    my $cwt  = $s->c( 'file', $wt );
    $s->p( sprintf( $mstr, $a, $sc, $cwt ) );

    # modules from config space
    my $modules = $s->get_ini_enabled_modules(
        { wt => $wt, ini => $i->{ini}, class => $classes } );
    foreach my $hr ( @{$modules} ) {
        my $m   = $hr->{name};     # module
        my $c   = $hr->{class};    # class
        my $cfg = $hr->{cfg};
        next
            if $scope ne 'all'
            and not( grep { $_ eq "$c:$m" } @{ $i->{mod} } );
        my $class = $hr->{location};
        $class =~ s{^$wt/}{}gmx;
        $class =~ s{/modules/.*}{}gmx;
        my $cm = $s->c( 'module', $m );
        my $cc = $s->c( 'module', $class );
        my $version
            = exists $cfg->{"version:$m"}->{file}
            ? $cfg->{"version:$m"}->{file}
            : 'unknown';
        $s->p( sprintf( "%s:%s %s\n", $cc, $cm, $version ) );
    }
    return 1;
}

sub applied { return 1; }

__PACKAGE__->meta->make_immutable;

1;
__END__

