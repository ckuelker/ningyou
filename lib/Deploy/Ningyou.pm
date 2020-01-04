# +---------------------------------------------------------------------------+
# | Deploy::Ningyou                                                           |
# |                                                                           |
# | Starting class for Ningyou deployment                                     |
# |                                                                           |
# | Version: 0.1.2 (change our $VERSION inside)                               |
# |                                                                           |
# | Changes:                                                                  |
# |                                                                           |
# | 0.1.2 2020-01-04 Christian Kuelker <c@c8i.org>                            |
# |     - print version and date time on startup                              |
# |                                                                           |
# | 0.1.1 2019-12-15 Christian Kuelker <c@c8i.org>                            |
# |     - VERSION not longer handled by dzil                                  |
# |                                                                           |
# | 0.1.0 2019-04-18 Christian Kuelker <c@c8i.org>                            |
# |     - initial release                                                     |
# |                                                                           |
# +---------------------------------------------------------------------------+
package Deploy::Ningyou;

# ABSTRACT: Starting class for Ningyou deployment

use Moose;
use Deploy::Ningyou::Action;
use Deploy::Ningyou::Provider;
use Data::Dumper;

our $VERSION = '0.1.2';

with qw(
    Deploy::Ningyou::Env
    Deploy::Ningyou::Util
    Deploy::Ningyou::Cfg
    Deploy::Ningyou::Execute
);

sub update {
    my ( $s, $i ) = @_;
    $i = $s->validate_parameter( { action => 1, ini => 1, opt => 1 }, $i,
        {} );

    my $verbose = $s->get_verbose($i);

    my $fn = '/var/cache/apt/pkgcache.bin';
    $s->e( "file not present [$fn]", 'bug' ) if not -f $fn;
    my $mt = $s->get_last_change_of_file($fn);
    $s->d("apt cache changed [$mt]");
    my $cache_ttl = $s->get_pm_cache_ttl( { ini => $i->{ini} } );    # 1 hour
    $s->d("apt cache time to live [$cache_ttl]");
    my $now = time;
    $s->d("time now [$now]");
    my $dt = $now - $mt;
    $s->d("delta t [$dt]");

    if ( $dt > $cache_ttl ) {
        $s->d("updateing cache [$dt] > [$cache_ttl]");

        $s->p("# Updating package manager cache\n")
            if $verbose and $i->{action} ne 'script';

        my ( $out, $err, $res ) = $s->execute_quite("aptitude update");
        my $r = ( $res == 0 ) ? 1 : 0;
        $s->p("$out\n") if $res;
        return $r;
    }
    else {
        $s->d("not updating cache [$dt] <= [$cache_ttl]");

        $s->p("# Not updating package manager cache\n")
            if $verbose and $i->{action} ne 'script';
        return 1;
    }
    return 0;
}

sub begin {
    my ( $s, $i ) = @_;

    # 1. check if debug is enabled
    my $fn = $s->get_debug_filename;
    $s->d( "=" x 80 );
    my $project = $s->get_project_version;
    my $dt = qx(date +'%FT%T');
    chomp $dt;
    $s->d("# Ningyou $project $dt\n");
    $s->d("NINGYOU_DEBUG [$fn]\n");

    # 2. init plugins
    my $action_plugins   = $s->enable_action_plugins;
    my $provider_plugins = $s->enable_provider_plugins;

    # 3. check command line options
    my $opt = $s->process_env_options($action_plugins); # Deploy::Ningyou::Env

    # 4. get action from command line (and modules)
    my $action = $s->get_env_action();                  # bootstrap, ...
    $s->e( "unknown action", 'action' ) if $action eq q{};
    $s->d("action [$action]");
    $s->p("# Ningyou $project $dt\n") if $action ne 'script';

    # 5. get aux modules from commandline
    my $mod = $s->env_modules();                        # [ zsh, default, ...]

    # 6. check and shorten commands Deploy::Ningyou::Action::*
    # basic checking is already done plugin aggregator class
    my $init
        = exists $action_plugins->{$action}->{init}
        ? $action_plugins->{$action}->{init}
        : sub { return 1; };
    my $apply
        = exists $action_plugins->{$action}->{apply}
        ? $action_plugins->{$action}->{apply}
        : $s->e( "no action - apply", 'action' );
    my $applied
        = exists $action_plugins->{$action}->{applied}
        ? $action_plugins->{$action}->{applied}
        : sub { return 1; };

    # 7. process commands
    if ( $action eq 'bootstrap' ) {    # bootstrap can not read cfg
        my $rep = $s->get_env_bootstrap_repository;
        if(defined $rep and $rep ne q{}){
            $s->p("About to bootstrap Ningyou to [$rep]\n");
        }else{ # happens for --main-configuration-only
            $s->p("About to bootstrap Ningyou main configuration only\n");
        }
        if ( $apply->( { opt => $opt, rep => $rep } ) ) {
            $s->p("Applied bootstrap\n");
        }
        else {
            $s->e( "Failed to apply bootstrap", 'removing' );
        }
    }
    else {                             # other commands that can read cfg

        my $ini = $s->get_ini;
        my $options = { ini => $ini, mod => $mod, opt => $opt };
        $s->update( { ini => $ini, opt => $opt, action => $action } )
            if $action eq 'status'
            or $action eq 'apply'
            or $action eq 'script';

        # init
        if ( $init->($options) ) {
            $s->d("init $action PASS");
        }
        else {
            $s->e( "init $action FAIL", 'cfg' );
        }

        # apply
        my ( $r, @script ) = $apply->($options);
        if ($r) {
            $s->d("apply $action PASS");
        }
        else {
            foreach my $line (@script) { chomp $line; $s->p("$line\n"); }
            $s->e( "execute $action FAIL [$r]", 'cfg' );
        }

        # applied
        if ( $applied->($options) ) {
            $s->d("applied $action PASS");
        }
        else {
            $s->e( "applied $action FAIL", 'cfg' );
        }
    }
}

sub enable_action_plugins {
    my ( $s, $i ) = @_;
    my $fn = $s->get_ini_filename;

    # set ini to {} is for bootstrap action
    my $ini = -f $fn ? $s->get_ini : Config::Tiny->new();

    my $na = Deploy::Ningyou::Action->new( { ini => $ini } );
    my $available_actions = $na->get_plugins();
    foreach my $c ( sort keys %{$available_actions} ) {
        $s->d("found action plugin class [$c]");
    }
    return $available_actions;
}

sub enable_provider_plugins {
    my ( $s, $i ) = @_;
    my $np        = Deploy::Ningyou::Provider->new();
    my $providers = $np->get_plugins();
    foreach my $c ( sort keys %{$providers} ) {
        $s->d("found provider plugin class [$c]");
    }
    return $providers;
}

#__PACKAGE__->meta->make_immutable;
no Moose;

1;
__END__

=pod

=head1 SYNOPSIS

    my $n = Deploy::Ningyou->new();
    $n->begin( {} );

=method update

Update the package manager cache.

=method begin

Start Ningyou deploy actions.

=method enable_action_plugins

Enable available command line arguments for ningyou command line tool.

=method enable_provider_plugins

Enable plugins that provide section functionality: [PROVIDER:*], like
'package', 'file', ...

=cut

