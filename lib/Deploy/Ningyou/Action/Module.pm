# +---------------------------------------------------------------------------+
# | Deploy::Ningyou::Action::Module                                           |
# |                                                                           |
# | Provides module argument action                                           |
# |                                                                           |
# | Version: 0.1.0 (change our $version inside)                               |
# |                                                                           |
# | Changes:                                                                  |
# |                                                                           |
# | 0.1.0 2019-04-12 Christian Kuelker <c@c8i.org>                            |
# |     - initial release                                                     |
# |                                                                           |
# +---------------------------------------------------------------------------+
package Deploy::Ningyou::Action::Module;

# ABSTRACT: Provides module argument action

use Cwd qw(cwd abs_path);
use Data::Dumper;
use Deploy::Ningyou::Class;
use File::Basename;
use Moose;
use namespace::autoclean;

has 'ini' => (
    isa    => 'Config::Tiny',
    is     => 'ro',
    reader => 'get_ini',
    writer => '_set_ini',

    #required=> 1, do not seem to work with Module::Pluggable
);

with qw(
    Deploy::Ningyou::Util
    Deploy::Ningyou::Util::Action
    Deploy::Ningyou::Host
    Deploy::Ningyou::Execute
);

our $version = '0.1.0';

# === [ main ] ================================================================
sub register { return 'module'; }

# subroutine input options
# parameter => 1=mandatory|0=optional
sub parameter             { return { opt => 1 }; }
sub parameter_description { return { opt => 'commandline options' }; }

# configuration input options
# param => description
sub attribute             { return {}; }
sub attribute_description { return {}; }

sub init {
    return 1;
}

sub apply {
    my ( $s, $i ) = @_;
    my $ini
        = exists $i->{ini} ? $i->{ini} : $s->e( "no [ini]", 'sp' );
    my $opt
        = exists $i->{opt} ? $i->{opt} : $s->e( "no [opt]", 'sp' );
    my $mod
        = exists $i->{mod} ? $i->{mod} : $s->e( "no [mod]", 'sp' );

    my $mc = scalar @{$mod};
    if ( $mc < 1 ) {
        $s->e( "No name!\nUSAGE: ningyou module <NAME>", 'usage' );
    }
    foreach my $m ( @{$mod} ) {
        $s->p( "setting up module [" . $s->c( 'module', $m ) . "]\n" );
    }

    # checks
    my $cwd = cwd();
    $s->p("we are in cwd [$cwd]\n");

    # check if we are under "modules"
    my $current   = basename( abs_path($cwd) );
    my $current_c = $s->c( 'no', $current );
    my $modules_c = $s->c( 'yes', 'modules' );
    my $e0 = "The current directory is not [$modules_c]\nit is [$current_c]";
    $s->e( $e0, 'wrong_dir' ) if $current ne 'modules';

    # check if we are under CLASS/modules
    my $class     = basename( dirname( abs_path($cwd) ) );
    my $nc        = Deploy::Ningyou::Class->new( { ini => $i->{ini} } );
    my $classes   = $nc->get_classes;
    my $classes_c = $s->c( 'yes', join q{, }, @{$classes} );
    my $class_c   = $s->c( 'no', $class );
    my $e1        = "The parent directory [$class_c] to not match\n";
    $e1 .= "a known class [$classes_c]";
    $s->e( $e1, 'wrong_dir' )
        if not grep { $_ eq $class } @{$classes};
    $s->p( "the current working directory is " . $s->c( 'ok', "OK" ) . "\n" );

    # check if we are in the correct working tree
    my $wt       = $s->get_worktree;
    my $exp_wt   = "$wt/$class/$current";
    my $exp_wt_c = $s->c( 'yes', $exp_wt );
    my $cwd_c    = $s->c( 'no', $cwd );
    $s->d("wt [$wt]");
    my $e2 = "Exepect to be in directory [$exp_wt_c]\nbut we are in [$cwd_c]";
    $s->e( $e2, 'wrong_dir' ) if $exp_wt ne $cwd;

    foreach my $module ( @{$mod} ) {
        $s->p( "create module [" . $s->c( 'module', $module ) . "] ...\n" );
        my @dir = ();
        if ( not -d $module ) {
            push @dir, $module;
            push @dir, "$module/files";
            push @dir, "$module/manifests";
            foreach my $dir (@dir) {
                my $dir_c = $s->c( 'directory', $dir );
                $s->p("make directory [$dir_c] ...\n");
                my $cmd = "mkdir -p $dir";
                my ( $out, $err, $res ) = $s->execute($cmd);
                if ( not $err ) {
                    my $str = "[%s] %s %s\n";
                    my $pass = $s->c( 'pass', 'PASS' );
                    $s->p( sprintf( $str, $pass, $cmd, $out ) );
                }
                else {
                    my $str = "[%s] %s %s %s\n";
                    my $fail = $s->c( 'fail', 'FAIL' );
                    $s->p( sprintf( $str, $fail, $cmd, $out, $err ) );
                }
            }
            my $rini = $s->apply_template(
                {
                    ini => $ini,
                    tpl => $s->module_ini( { module => $module } )
                }
            );
            $s->d($rini);
            my $fn = "$module/manifests/$module.ini";
            open my $fh, q{>}, $fn or die "ERR: can not write [$fn]";
            print $fh $rini;
            close $fh;
            my $fn_c = $s->c( 'file', $fn );
            $s->p("created file [$fn_c], please edit\n") if -f $fn;
        }
        else {
            my $module_c = $s->c( 'no', $module );
            $s->e( "Directory [$module_c] already exists", 'dir_exists' );
        }
    }
    return ( 1, [] );
}

sub applied {
    return 1;
}

sub module_ini {
    my ( $s, $i ) = @_;
    my $module
        = exists $i->{module}
        ? $i->{module}
        : $s->e( 'no [module]', 'sp' );
    my $author = qx(git config user.name);
    chomp $author;
    my $email = qx(git config user.email);
    chomp $email;
    my $date = $s->get_date;
    my $changes
        = sprintf( "; | 0.1.0 %s %s <%s> ", $date, $author, $email )
        . q{ } x 80;
    $changes = substr $changes, 0, 77;
    my $fn = "modules/$module/manifests/$module.ini";
    my $head = sprintf "; | %-73s |", $fn;

    return <<"INI";
; +---------------------------------------------------------------------------+
$head
; |                                                                           |
; | Configuration for a Ningyou module.                                       |
; |                                                                           |
; | Version: 0.1.0 (Change also inline: [version] file=)                      |
; |                                                                           |
; | Changes:                                                                  |
; |                                                                           |
$changes |
; |     - initial release                                                     |
; |                                                                           |
; +---------------------------------------------------------------------------+
;
[version:$module]
; Ningyou Project version - changed by Ningyou
project=[% PROJECT %]
; Ningyou Configuration Space version - changed by Ningyou
configuration=[% CONFIGURATION %]
; version of this file - change this when you update the file
file=0.1.0

; uncomment the following lines for special debug purposes
;[nop:$module]
; the 'nop' provider provides a 'no operation' - nothing
; can be used to check (via debug) if configuration section is actually used
; it should be disabled by commenting out, because it will be always pending
;debug=Message for module [$module] debug

; edit and uncomment the following lines to match your plan
;[package:$module]
;ensure=latest

INI

}

__PACKAGE__->meta->make_immutable;

1;
__END__

