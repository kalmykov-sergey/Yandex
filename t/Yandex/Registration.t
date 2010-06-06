#!/usr/bin/perl
use strict;

use lib '../../lib';
use Data::Dumper;
use Test::More 'no_plan';
use_ok('Yandex::Account::Registration');

ok(my $reg = Yandex::Account::Registration->new(), "Registration object created");
like($reg->get_captcha, qr'^http://', "Captcha looks like url");
isnt($reg->send_captha, '000000', "wrong captcha processing");


