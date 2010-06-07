#!/usr/bin/perl
use strict;

use lib '../../lib';
use Data::Dumper;
use Test::More 'no_plan';
use_ok('Yandex::Account::Registration');

my $iname = Yandex::Account::Registration::rand_iname();
my $fname = Yandex::Account::Registration::rand_fname();
like($iname, qr/\S/, "$iname is a name");
like($fname, qr/\S/, "$fname is a name");
