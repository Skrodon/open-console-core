
use Test::More;

use OpenConsole::Util qw/domain_suffix/;

sub run($$)
{	my ($name, $parts) = @_;
#use Data::Dumper; warn Dumper +[ domain_suffix $name ], $parts;
	is_deeply +[ domain_suffix $name ], $parts, $name;
}

run 'nl', [ undef, undef, 'nl' ];
run 'nlnet.nl', [ undef, 'nlnet', 'nl' ];
run 'www.nlnet.nl', [ 'www', 'nlnet', 'nl' ];
run 'www.bbc.co.uk', [ 'www', 'bbc', 'co.uk' ];

run 'kawasaki.jp', [ undef, 'kawasaki', 'jp' ];   # !city.kawa
run 'xx.city.kawasaki.jp', [ 'xx.city', 'kawasaki', 'jp' ];   # !city.kawa
run 'www.night.hotel.kawasaki.jp', [ 'www', 'night', 'hotel.kawasaki.jp' ];    # *.kawa

done_testing;
