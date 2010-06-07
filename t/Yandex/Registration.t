#!/usr/bin/perl
use strict;

use lib '../../lib';
use Data::Dumper;
use Test::More 'no_plan';
use_ok('Yandex::Account::Registration');

ok(my $reg = Yandex::Account::Registration->new(), "Registration object created");
my $src = $reg->get_captcha();
like($src, qr'^http://', "Captcha url is $src");
my $file = $reg->{store};
ok($reg = Yandex::Account::Registration->new({}, $file), "Retrieving stored object");
is($reg->send_captcha('123456'), 0, "wrong captcha processing");


