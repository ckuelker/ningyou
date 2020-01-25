# +---------------------------------------------------------------------------+
# | Deploy::Ningyou::Provider::Crontab                                        |
# |                                                                           |
# | Provides crontab management                                               |
# |                                                                           |
# | Version: 0.1.0 (change our $VERSION inside)                               |
# |                                                                           |
# | Changes:                                                                  |
# |                                                                           |
# | 0.1.0 2020-01-24 Christian Kuelker <c@c8i.org>                            |
# |     - initial release                                                     |
# |                                                                           |
# +---------------------------------------------------------------------------+
package Deploy::Ningyou::Provider::Crontab;

# ABSTRACT: Provides crontab management

use Data::Dumper;
use Config::Crontab;
use Moose;
use namespace::autoclean;

has 'cmd' => (
    isa     => 'ArrayRef',
    is      => 'rw',
    reader  => 'get_cmd',
    writer  => 'set_cmd',
    default => sub { return []; },
);

has 'dst' => (
    isa     => 'Str',
    is      => 'rw',
    reader  => 'get_dst',
    writer  => 'set_dst',
    default => q{},
);

with qw(
    Deploy::Ningyou::Util
    Deploy::Ningyou::Cfg
    Deploy::Ningyou::Execute
    Deploy::Ningyou::Util::Provider
);

our $VERSION = '0.1.0';
our $CACHE   = {};

sub register { return 'crontab'; }

sub parameter {
    return { loc => 1, cfg => 1, sec => 1, opt => 1, dry => 0, };
}

sub parameter_description {
    return {
        loc => 'location of the configuration file',
        cfg => 'configuration snippet of a section',
        sec => 'section of the configuration file',
        opt => 'commandline options',
        dry => 'dry run for ::Script',
    };
}

sub parameter_default { return { dry => 1 }; }

# configuration input options
sub attribute {
    return {
        comment  => 0,
        dom      => 0,
        dow      => 0,
        ensure   => 1,
        hour     => 0,
        minute   => 0,
        month    => 0,
        require  => 0,
        variable => 0,
    };
}    # parameter => 1=mandatory|0=optional

sub attribute_default {
    return {
        comment  => '',
        dom      => '*',
        dow      => '*',
        ensure   => 0,
        hour     => '*',
        minute   => '*',
        month    => '*',
        require  => 0,
        variable => 0,
    };
}

# module configuration attributes
sub attribute_description {

    # provided by Deploy::Ningyou::Attribute::*
    return {
        comment  => 'comment',
        dom      => 'day of month',
        dow      => 'day of week',
        ensure   => 'ensure: enabled|disabled',
        hour     => 'hour',
        minute   => 'minute',
        month    => 'month',
        require  => 'require this other entity (provider)',
        variable => 'variable definition: variable=KEY:VALUE',

    };
}    # param => description

sub init   { return 1; }
sub script { return 0; }
sub apply  { my ( $s, $i ) = @_; return $s->standard_apply($i); }

sub applied {
    my ( $s, $i ) = @_;
    my ( $v, $sec, $cls, $prv, $search, $cfg, $c, $loc, $ok )
        = $s->applied_in( { i => $i } );
    $s->e( 'section is not OK', 'cfg' ) if not $ok;

    # host.domain.tld:crontab:command
    $s->d("provider crontab [$sec]");
    my ( $sc, $sp, $id ) = $s->parse_section($sec);
    my ( $o, $cmd ) = $s->parse_id($id);

    $s->d("section [$sc][$sp][$id]\n");
    $s->d("owner   [$o]\n");
    $s->d("cmd     [$cmd]\n");
    my $sec_c    = $s->c( 'module',    $sec );
    my $loc_c    = $s->c( 'file',      $i->{loc} );
    my $hint     = "\nin file [$loc_c]\nat section [$sec_c]";
    my $ensure_c = $s->c( 'attribute', $c->{ensure} );

    # Overview:
    # A check attributes
    # B owner exists
    # C read crontab
    # D check for changes
    # E aggregate command

    # A check attributes
    if ( $c->{ensure} eq 'enabled' ) {
        $s->d('esure=enabled');
    }
    elsif ( $c->{ensure} eq 'disabled' ) {
        $s->d('esure=disabled');
    }
    else {
        $s->e( "Wrong value [$ensure_c] for [ensure]$hint", 'cfg' );
    }

    # B owner exists
    my $owner_not_exists = qx(id -u $o>/dev/null 2>&1;echo \$?);
    chomp $owner_not_exists;
    $s->e( "No such owner [$o]", 'cfg' ) if $owner_not_exists;

    # C read crontab
    $s->d("owner [$o]");
    my $ct = Config::Crontab->new();
    $ct->owner($o);
    $ct->read;
    my ($event) = $ct->select( -command_re => "$cmd" );
    $s->d( Dumper( \$event ) );

    # D check for changes
    my $return = 1;
    my $new    = 0;
    my @attr   = qw(minute hour month dom dow comment);
    my @cmd    = ();
    my $pfx    = "crontab ($cmd) =>";
    my %change = ();
    foreach my $attr (@attr) {
        my $val = $c->{$attr};
        $s->d("attr [$attr]=[$val]\n");
        if ( defined $event ) {    # old entry
            if ( exists $c->{$attr} and $c->{$attr} eq $event->$attr ) {
                $s->d("attribute [$attr] equal\n");
            }
            else {
                my $cval = $event->minute;
                my $v    = "$pfx \n#    attribute [$attr] not equal:";
                $v .= " [$cval](crontab)";
                $v .= "[" . $event->$attr . "]";
                $v .= " != [$val] ($loc)";
                push @cmd, { verbose => $s->c( 'no', $v ) };
                $s->d("$v\n");
                $change{$attr} = $val;
                $return = 0;
            }
        }
        else {    # new entry
            $return = 0;
            $new    = 1;
            $event  = new Config::Crontab::Event( -command => $cmd );
            $event->$attr($val);
            my $block = new Config::Crontab::Block;
            $block->last($event);
            $ct->last($block);
            my $v = "$pfx\n#    no entry: add new entry ($loc) [$attr]";
            push @cmd, { verbose => $s->c( 'no', $v ) };
            $change{$attr} = $val;
        }
    }
    if ( defined $event ) {
        my $active = $event->active;
        if ( $c->{ensure} eq 'enabled' and $active ) {
            $s->d('nothing to do (active event is enabled');
        }
        elsif ( $c->{ensure} eq 'enabled' and not $active ) {
            my $v = qq{$pfx event should be active => enable it};
            push @cmd, { verbose => $s->c( 'no', $v ) };
            $return = 0;
        }
        elsif ( $c->{ensure} eq 'disabled' and $active ) {
            my $v = qq{$pfx event should not be active => disable it};
            push @cmd, { verbose => $s->c( 'no', $v ) };
            $return = 0;
        }
    }
    else {    # new event
        $s->d('nothing to do (no event)');
    }

    # E aggregate command
    # (consider executing this directly in Perl and not bash)
    my $ex = qq{\$c=new Config::Crontab;\$c->owner(q{$o});\$c->read;};
    if ($new) {
        $ex .= qq{\$e=new Config::Crontab::Event(-command => q{$cmd});};
        $ex .= q{$b=new Config::Crontab::Block;};
        $ex .= q{$b->last($e);};
        $ex .= q{$c->last($b);};
    }
    $ex .= qq{(\$e)=\$c->select(-command=>q{$cmd});};
    foreach my $attr ( sort keys %change ) {
        my $val = $change{$attr};
        $ex .= qq{\$e->$attr(q{$val});};
    }
    $ex .= q{$e->active(1);} if $c->{ensure} eq 'enabled';
    $ex .= q{$e->active(0);} if $c->{ensure} eq 'disabled';

    # NOT IMPLEMENTED (jet?)
    # problem: REMOVES complete crontab, but not event or block
    # if ( $c->{ensure} eq 'missing' ) {
    #    $ex .= '$b=$c->block($e);';
    #    $ex .= '$c->remove($b);'; # REMOVED complete crontab
    #    $ex .= '$b->dump;'; # not needed, remove when/if fixed
    #}
    $ex .= q/$c->write or do { warn "ERR: ".$c->error."\n";return;};/;
    my $perl = qq{perl -MConfig::Crontab -e '$ex'};
    push @cmd, { cmd => $perl, verbose => $s->c( 'no', 'update crontab' ) };

    $s->set_cmd( \@cmd );
    return $return;
}

sub parse_id {
    my ( $s, $id ) = @_;
    my ( $owner, $cmd ) = split m/\s*:\s*/, $id;
    chomp $owner;
    chomp $cmd;
    return ( $owner, $cmd );
}

__PACKAGE__->meta->make_immutable;

1;
__END__

