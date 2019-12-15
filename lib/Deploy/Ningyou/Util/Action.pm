# +---------------------------------------------------------------------------+
# | Deploy::Ningyou::Util::Action                                             |
# |                                                                           |
# | Utilities for Action                                                      |
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
package Deploy::Ningyou::Util::Action;

# ABSTRACT: Utilities for Action

use warnings;
use strict;
use File::Find;
use Moose::Role;

with qw(Deploy::Ningyou::Util);

our $VERSION = '0.1.1';

# --- [ Action ] --------------------------------------------------------------
# all | zsh vim default ...
# 1. scope is all if nothing is specified on command line
# 2. scope is all if all is specified on command line
# 3. scope is modules if not all is specified on command line
#   (and at least one modules)
# 4. scope is all if all and some modules are specified on command line
#        1.    2.        3.        4.
# $modules = [ ] | [ all ] | [ vim ] | [ all, vim ]
#
#    Deploy/Ningyou/Action/Status.pm
#    Deploy/Ningyou/Action/Apply.pm
#    Deploy/Ningyou/Action/List.pm
sub parse_scope {
    my ( $s, $modules ) = @_;
    my $scope
        = ( grep { $_ eq 'all' } @{$modules} ) ? 'all'
        : scalar @{$modules} > 0 ? join( q{ }, @{$modules} )
        :                          'all';
    return $scope;
}

# /tmp/ningyou/global/modules/default => default
# /tmp/ningyou/global/modules/vim     => vim
# mp: module_path
sub module_path_to_class_module {
    my ( $s, $i ) = @_;
    my $mp = exists $i->{mp} ? $i->{mp} : $s->e( 'no [mp]', 'sp' );
    my $wt = $s->get_worktree;
    $mp =~ s{^$wt/}{}gmx;
    my ( $class, $module ) = split m{/modules/}, $mp;
    return ( $class, $module );
}

sub find_module_paths {
    my ( $s, $i ) = @_;
    my $wt = exists $i->{wt} ? $i->{wt} : $s->e( 'no [wt]', 'sp' );

    my @m = ();
    find( sub { push @m, "$File::Find::dir$/" if (/manifests$/); }, $wt );
    foreach my $m (@m) { chomp $m }

    # '$wt/debian-gnu-linux-9.8-stretch-amd64-x86_64/modules/default',
    # '$wt/global/modules/default',
    # '$wt/global/modules/zsh',
    # '$wt/w1.c8i.org/modules/default
    return \@m;
}

no Moose::Role;

1;
__END__

