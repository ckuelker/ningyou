use strict;
use warnings;
use diagnostics;
#use Test::More "no_plan";
use Test::More;

BEGIN {
    use_ok('Ningyou');
    use_ok('Ningyou::Cmd');
    use_ok('Ningyou::Util');
    use_ok('Ningyou::Options');
    use_ok('Ningyou::Provider::Cpan');
    use_ok('Ningyou::Provider::Directory');
    use_ok('Ningyou::Provider::File');
    use_ok('Ningyou::Provider::Git');
    use_ok('Ningyou::Provider::Link');
    use_ok('Ningyou::Provider::Package');
    use_ok('Ningyou::Provider::Service');
}
done_testing()
