use strict;
use warnings;
use diagnostics;
#use Test::More "no_plan";
use Test::More;

BEGIN {
    use_ok('Deploy::Ningyou::Action::Apply');
    use_ok('Deploy::Ningyou::Action::Bootstrap');
    use_ok('Deploy::Ningyou::Action::List');
    use_ok('Deploy::Ningyou::Action::Module');
    use_ok('Deploy::Ningyou::Action::Script');
    use_ok('Deploy::Ningyou::Action::Status');
}
done_testing()
