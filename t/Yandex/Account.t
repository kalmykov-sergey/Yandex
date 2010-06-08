#!/usr/bin/perl -w
use strict;

use lib '../../lib';
use Data::Dumper;
use Test::More 'no_plan';
use_ok('Yandex::Account');

my $rand_account = Yandex::Account->new_random();
#die Dumper $rand_account;
like($rand_account->ip, qr/\d+\./, 'account->ip looks like ip' );
isa_ok($rand_account->sites, 'ARRAY', 'account->sites');

my $site_account = Yandex::Account->new_from_site('admos.ru');
diag( "Account '". $site_account->{login} ."' created by new_from_site constructor\n". Dumper($site_account) );
ok(scalar @{$site_account->sites} > 0, 'and it has non-empty list of sites');
my $ip = Yandex::Account::new_ip();
like($ip, qr/\d+\./, "choose non-binded ip: $ip");

#my $new_acc = Yandex::Account->new();
#$new_acc->delete;