use strict;
use warnings;
use diagnostics;
#use Test::More "no_plan";
use Test::More;

BEGIN {
    use_ok('Deploy::Ningyou::Provider::File');
}

my $npf = Deploy::Ningyou::Provider::File->new;
my $got_register = $npf->register;
my $expect_register  = 'file';
is($got_register,$expect_register,'register is [file]');

done_testing()
