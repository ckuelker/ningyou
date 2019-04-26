use strict;
use warnings;
use diagnostics;
#use Test::More "no_plan";
use Test::More;

BEGIN {
    use_ok('Deploy::Ningyou::Provider::Directory');
    use_ok('Deploy::Ningyou::Provider::File');
    use_ok('Deploy::Ningyou::Provider::Git');
    use_ok('Deploy::Ningyou::Provider::Link');
    use_ok('Deploy::Ningyou::Provider::Nop');
    use_ok('Deploy::Ningyou::Provider::Package');
    use_ok('Deploy::Ningyou::Provider::Rsync');
    use_ok('Deploy::Ningyou::Provider::Version');
}
done_testing()
