# +---------------------------------------------------------------------------+
# | Deploy::Ningyou::Action::Checksum                                         |
# |                                                                           |
# | Provides checksum argument action                                         |
# |                                                                           |
# | Version: 0.1.1 (change our $VERSION inside)                               |
# |                                                                           |
# | Changes:                                                                  |
# |                                                                           |
# | 0.1.1 2020-01-30 Christian Kuelker <c@c8i.org>                            |
# |     - support ningyou URL ningyou://                                      |
# |                                                                           |
# | 0.1.0 2020-01-04 Christian Kuelker <c@c8i.org>                            |
# |     - initial release                                                     |
# |                                                                           |
# +---------------------------------------------------------------------------+
package Deploy::Ningyou::Action::Checksum;

# ABSTRACT: Provides checksum argument action

use strict;
use warnings;

# TODO: Can Config::IniFiles be replaced by Config::INI::Reader?
#use Config::INI::Reader;
use Data::Dumper;
use Moose;
use namespace::autoclean;
use Deploy::Ningyou::Class;
use Deploy::Ningyou::Dependency;

# 2020-01-04
use Config::IniFiles;
use File::Basename;

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
    Deploy::Ningyou::Modules
    Deploy::Ningyou::Host
);

our $VERSION = '0.1.1';

sub register              { return 'checksum'; }
sub parameter             { return { module => 0, }; }
sub parameter_description { return { module => 'name of module' }; }
sub attribute             { return {}; }
sub attribute_description { return {}; }
sub init                  { return 1; }
sub applied               { return 1; }

# apply
# IN:
#     ini: global configuration ~/.ningyou.ini {}
#     mod: modules from command line           []
#     opt: command line options                {}
sub apply {
    my ( $s, $i ) = @_;
    $i = $s->validate_parameter( { ini => 1, mod => 1, opt => 1 }, $i, {} );
    my $verbose = $s->get_verbose($i);    # opt
    $s->p("WARNING: this command changes the configuration. It depends on\n");
    $s->p("         Config::IniFiles to write the configuration back.\n");
    $s->p("         While this module is quite smart and preserves order\n");
    $s->p("         and comments, it is not bullet prove. It might\n");
    $s->p("         produce invalid configuration. For example it will\n");
    $s->p(
        "         merge attributes of duplicated sections. Make a backup\n");
    $s->p("         or commit to git before using this experimental\n");
    $s->p("         command.\n");
    my $updated = 0;
    my $found   = 0;
    my @sec     = ();
    my %before  = ();
    my %after   = ();

    $s->e( "no file given on command line", 'usage' )
        if not exists $i->{mod}->[0];
    $s->d( Dumper( $i->{mod} ) );
    my $cwd = qx(pwd);
    chomp $cwd;
    $s->d("cwd[$cwd]\n");
    my $ok = $s->c( 'yes', 'OK' );
    my $ng = $s->c( 'no',  'NG' );
    my $fn = "$cwd/$i->{mod}->[0]";
    if ( -f $fn ) {    # do file exist
        $s->d("fn [$fn]\n");
        my $wt = $s->get_worktree;
        $s->d("wt [$wt]\n");
        if ( $fn =~ m{^$wt}gmx ) {    # is file in worktree?
            my $bfn = $fn;
            $bfn =~ s{/files/.*}{}gmx;
            $s->d("bfn[$bfn]\n");
            my @suffixlist = qw();
            my ( $name, $path, $suffix ) = fileparse( $bfn, @suffixlist );
            $s->d("name[$name]path[$path]\n");
            my $cfn = "$path/$name/manifests/$name.ini";

            if ( -e $cfn ) {
                $s->d("cfn [$cfn]\n");
                my $cfg = Config::IniFiles->new( -file => $cfn );
                foreach my $sec ( $cfg->Sections ) {
                    next if not $sec =~ m{file:}gmx;
                    $s->d("* SECTION sec [$sec]: ");
                    next if not $cfg->exists( $sec, "source" );
                    next if not $cfg->exists( $sec, "checksum" );
                    my $src = $cfg->val( $sec, "source" );
                    $src =~ s{ningyou://}{$wt/}gmx;
                    $src =~ s{//}{/}gmx;
                    if ( $src eq $fn ) {
                        $s->d("    $ok sec [$sec]\n");
                        $s->d("    $ok fn  [$fn]\n");
                        $found = 1;
                        push @sec, $sec;

                        # TODO: consider using Deploy::Ningyou::Util::Provider
                        # my $cs = $s->get_md5(undef,$fn);
                        #print "cs [$cs]\n";
                        my $ctx = Digest::MD5->new;
                        open my $f, q{<}, $fn or die "Can not read [$fn]!\n";
                        $ctx->addfile($f);
                        my $digest = $ctx->hexdigest;
                        close $f;
                        $s->d("    calculate md5 [$digest]");
                        $s->d("    digest[$digest]\n");
                        my $val = $cfg->val( $sec, "checksum" );
                        push @{ $before{$sec} }, $val;
                        push @{ $after{$sec} },  $digest;

                        if ( $val ne $digest ) {
                            $cfg->setval( $sec, "checksum", $digest );
                            $s->d("write [$cfn]\n");
                            $cfg->WriteConfig($cfn);
                            $s->p("changed section [$sec]:\n");
                            $s->p("    checksum=$digest\n");
                            $s->p("wrote [$cfn]\n");
                            $updated++;
                        }
                    }
                    else {
                        $s->d("    $ng src[$src]");
                        $s->d("    $ng fn [$fn]\n");
                    }
                }
            }
            else {
                $s->e( "not configuration at [$cfn]", 'cfg' )
                    ;    # TODO: correct hint
            }

        }
        else {
            $s->e( "file [$fn] not in worktree [$wt]", 'cfg' )
                ;        # TODO: correct hint
        }
    }
    else {
        $s->e( "no file [$fn]", 'cfg' );    # TODO: correct hint
    }
    $s->p("found the following section(s):\n") if $found;
    foreach my $sec (@sec) {
        $s->p("- section [$sec]\n");
        foreach my $b ( @{ $before{$sec} } ) {
            $s->p("  before [$b]\n");
        }
        foreach my $b ( @{ $after{$sec} } ) {
            $s->p("  after [$b]\n");
        }
    }
    $s->p("updated [$updated] attribute(s)\n");
    return 1;

}

__PACKAGE__->meta->make_immutable;

1;

__END__

