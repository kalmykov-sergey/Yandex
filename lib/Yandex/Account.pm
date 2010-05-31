package Yandex::Account;

use strict;
use warnings;

use DBI;


sub new_random {
  my $class = shift;
  my $sql_fetch_random = "
    select * from yandex_accounts order by rand()
  ";
  return $class->_new($sql_fetch_random);
} # ����������� - ��������� ������� �������


sub new_from_site {
  my ($class, $site) = @_;
  my $sql_fetch_by_site = "
    select yandex_accounts.id, login, password, ip 
    from yandex_accounts left join yandex_sites 
    on yandex_accounts.id = yandex_sites.account_id
    where yandex_sites.url like '$site'
  ";
  return $class->_new($sql_fetch_by_site);
} # ����������� - (���� ��) ������� ���������� �����


sub _new {
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
} # ��������� ����������� - ������� �� sql-�������


sub ip {
  my $self = shift;
  return $self->{ip};
} # ip ��� xml-��������


sub sites {
  my $self = shift;
  return $self->{sites};
} # ������ ������ ���������� ������� ��������


1;

__END__

=pod
  �����-������� �������, ������������ ��� xml-�������� � ��������� � ����������.
  ������ � ��������� seo.yandex_accounts � seo.yandex_sites
=cut