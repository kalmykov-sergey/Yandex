#!/usr/bin/perl -w
use strict;

use lib '../../lib';
use Data::Dumper;
use Test::More 'no_plan';
use_ok('Yandex::Account::UA');

ok(my $acc = Yandex::Account::UA->new('ya.vasja.pupkin', 'shkola91'), "construct");
ok($acc->authenticate, "authenticate");
ok($acc->register_ip('93.191.8.223'), "ip register");
