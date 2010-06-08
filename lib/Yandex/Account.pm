package Yandex::Account;

use strict;
use warnings;

use DBI;
use Data::Dumper;
use Yandex::Account::UA;

sub ip_stack {
  my @ips = ();
  for(96..127) {push @ips, '93.191.8.'.$_}
  for(192..223) {push @ips, '93.191.8.'.$_}
  for(128..191) {push @ips, '93.191.15.'.$_}
  return @ips;
}

sub new_ip {
  my $dbh = DBI->connect('dbi:mysql:database=seo;host=mail.plarson.ru', 'lavan', 'Gh2mooK6C');
  my $selected_ips = $dbh->selectall_arrayref("select ip from yandex_accounts");
  $dbh->disconnect;
  my %ips = map{$_ => 1} grep{$_} map{$_->[0]} @$selected_ips;
  my @free_ips = grep{not $ips{$_}} ip_stack();
  die "no free ip" unless scalar @free_ips;
  return $free_ips[int rand($#free_ips)];
}

sub new {
  my ($class, $login, $password, $ip) = @_;
  $ip ||= new_ip();
  my $ua = Yandex::Account::UA->new($login, $password);
  $ua->authenticate;
  $ua->register_ip($ip);
  my $dbh = DBI->connect('dbi:mysql:database=seo;host=mail.plarson.ru', 'lavan', 'Gh2mooK6C');
  $dbh->do("
    insert into yandex_accounts (login, password, ip) values (?, ?, ?)
  ", {}, $login, $password, $ip);
  my $row = $dbh->selectrow_hashref("select * from yandex_accounts where id=?", {}, $dbh->{'mysql_insertid'});
  $dbh->disconnect;
  my $self = $row;
  bless $self, $class;
}


sub new_random {
  my $class = shift;
  my $sql_fetch_random = "
    select * from yandex_accounts order by rand()
  ";
  return $class->_fetch($sql_fetch_random);
} # конструктор - случайный аккаунт яндекса


sub new_from_site {
  my ($class, $site) = @_;
  my $sql_fetch_by_site = "
    select yandex_accounts.id, login, password, ip 
    from yandex_accounts left join yandex_sites 
    on yandex_accounts.id = yandex_sites.account_id
    where yandex_sites.url like '$site'
  ";
  return $class->_fetch($sql_fetch_by_site);
} # конструктор - (один из) аккаунт вебмастера сайта


sub _fetch {
  my ($class, $query) = @_;
  my $dbh = DBI->connect('dbi:mysql:database=seo;host=mail.plarson.ru', 'lavan', 'Gh2mooK6C');
  my $row = $dbh->selectrow_hashref($query);
  my $sites = $dbh->selectall_arrayref("
    select * from yandex_sites where account_id = ?
  ", {Slice => {}}, $row->{id});
  my $self = $row;
  $self->{sites} = $sites;
  $dbh->disconnect;
  bless $self, $class;
} # приватный конструктор - аккаунт по sql-запросу


sub ip {
  my $self = shift;
  return $self->{ip};
} # ip для xml-запросов


sub sites {
  my $self = shift;
  return $self->{sites};
} # список сайтов вебмастера данного аккаунта

sub all_ips {
  my $dbh = DBI->connect('dbi:mysql:database=seo;host=mail.plarson.ru', 'lavan', 'Gh2mooK6C');
  my $all = $dbh->selectall_arrayref("
    select ip from yandex_accounts
  ", {Slice => {}});
  my @ips = map{$_->{ip}} @$all;
  $dbh->disconnect;
  return @ips;
}

=pod
sub register {
  my ($iname, $fname, $ip) = @_;
  my $registration = Yandex::Account::Registration->new($iname, $fname);
  my $dbh = DBI->connect("dbi:mysql:seo", 'lavan', 'Gh2mooK6C');
  $dbh->do("
    insert into yandex_accounts (login, password, ip) values (?, ?, ?)
  ", {}, $self->login, 'shkola91', $ip);
  $dbh->disconnect;
}
=cut

1;

__END__

=pod
  Класс-аккаунт яндекса, используется для xml-запросов и обращения к вебмастеру.
  Связан с таблицами seo.yandex_accounts и seo.yandex_sites
=cut