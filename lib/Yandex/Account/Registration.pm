package Yandex::Account::Registration;

use strict;
use warnings;

use LWP;
use HTML::Form;
use locale;
use Data::Dumper;
use Storable;
use Digest::MD5 qw(md5_hex);
use Encode;
use DBI;

=pod

	#!/usr/bin/perl -w

	use CGI qw(:standard);
	use Yandex::Account::Registration;

    $reg = Yandex::Account::Registration->new();
    $url = $reg->get_captcha();
    $filename = $reg->{store};
    ---
    $filename = param('store');
    $code = param('code');
    $reg = Yandex::Account::Registration->new({}, $filename);
    if (my $ok = $reg->send_captcha($code)){
      $reg->save_to_db;
    }

=cut


sub new {
  my ($class, $hash_ref, $file_to_retrieve) = @_;


  my $ua = LWP::UserAgent->new(
    agent => 'Mozilla 5.0 (MSIE 8.0)',
    requests_redirectable => ['GET', 'POST'],
  );
  $ua->cookie_jar({
#    file => 'cookies.lwp', 
#    autosave => 1
  });
  my $iname = $hash_ref->{iname} || rand_iname();
  my $fname = $hash_ref->{fname} || rand_fname();
  
  my $self = {ua => $ua, iname => $iname, fname => $fname};
  bless $self, $class;

  if($file_to_retrieve){
    $Storable::Eval = 1;
    my $stored = retrieve($file_to_retrieve);
    $self->{store} = $file_to_retrieve;
    $self->{ua}->cookie_jar($stored->{cookie_jar});
    $self->{form2} = $stored->{form};
  } else {
    $self->{ua}->get('http://xml.yandex.ru'); # ��� �����
  }

  return $self;
}


sub _step1 {
  my $self = shift;
  my $resp1 = $self->{ua}->get(
    'http://passport.yandex.ru/passport?mode=register&retpath=http://xml.yandex.ru/'
  );
  die $resp1->status_line unless $resp1->is_success;

  # �������� ������� ����� � ��� ������������ �������, 
  # ����� �������� ��������� - ������ ��������� �������
  my $login = _create_login($self->{iname}, $self->{fname});

  my $form1 = HTML::Form->parse($resp1);
  $form1->value(iname => $self->{iname});
  $form1->value(fname => $self->{fname});
  $form1->value(login => $login);
  my $resp2 = $self->{ua}->request($form1->click);
  die $resp2->status_line unless $resp2->is_success;

  if($resp2->content =~ m{class="loginlist visible"}){ # ������ ��������� �������
    # ������� �������� (��� �������) ����� 
    $login = _parse_yandex_logins($resp2->content);
    $form1 = HTML::Form->parse($resp2);
    $form1->value(iname => $self->{iname});
    $form1->value(fname => $self->{fname});

    # �������� ����� � ���������� �������
    $form1->value(login => $login);
    $resp2 = $self->{ua}->request($form1->click);
  } else {
    # ������ ������ ���, �.�. ����� �������������� ������
  }

  $self->{login} = $login;
  return $resp2;
}


sub get_captcha {
  my $self = shift;
  my $resp2 = $self->_step1;
  die $resp2->status_line unless $resp2->is_success;
  my $html = $resp2->content;

  my $src = $1 if $html =~ m{class="captcha-img" src="([^"]*)"};
  $self->{ua}->get($src); # ��� ����� �����, ����� ����������� �� �������
  unless($src){
    open my $w, '>whereiscaptcha.html';
    print $w $html;
    close $w;
    die "�� ����� ������ �����"; 
  }

  # ��������� ������ � ����� $rand_file_name
  my $rand_file_name = md5_hex($self) . '.storable';
  $self->{resp2} = $resp2;
  $self->{store} = $rand_file_name;
  $self->{src} = $src;
#  die Dumper $self;

  my $form2 = HTML::Form->parse($resp2);
  $form2->value(passwd => 'shkola91'); # ������ ����� �������� ���������
  $form2->value(passwd2 => 'shkola91');
  $form2->value(hintq => 3); # ���������� ��������� ����� �� 0 �� 5
  $form2->value(hinta => 'I have no dog'); # � ����� ����� �� ��������� ������
#  $form2->value(code => $code);

  $Storable::Deparse = 1;
  store {
    form => $form2, 
    cookie_jar => $self->{ua}->cookie_jar
  }, $rand_file_name;
 
  return $src;
}


sub send_captcha {
  my $self = shift;
  my $code = shift;

  my $form2 = $self->{form2};

  $form2->value(passwd => 'shkola91'); # ������ ����� �������� ���������
  $form2->value(passwd2 => 'shkola91');
  $form2->value(hintq => 3); # ���������� ��������� ����� �� 0 �� 5
  $form2->value(hinta => 'I have no dog'); # � ����� ����� �� ��������� ������
  $form2->value(code => $code);
  
  my $req = $form2->click;
  $self->{ua}->prepare_request($req);
#  die Dumper($req);
  my $resp3 = $self->{ua}->request($req);

  my $html = encode('cp1251', decode('utf-8', $resp3->content));

  if($html =~ /�� ����������� ����� ����������� �����./){
    unlink $self->{store} if $self->{store};
    return 0;
  }
  if($html =~ /������ ��������� �������/){
    die "bad request (?):\n", Dumper ($req);
  }
  if($html =~ /\(Cookies\)/){
    die $req->as_string, "\n���������� �������� ���� (Cookies)";
  }
  unless($html =~ /�����������/){
    open my $w, '>resp3.html';
    print $w $html;
    close $w;
    die "����������� ������";
  }
  
  $self->{ua}->get('http://passport.yandex.ru/passport?mode=logout'); # ��� ������� �����
  unlink $self->{store} if $self->{store};
  return 1;
}


sub _parse_yandex_logins {
  my $html = shift;
  my $login = $1 if $html =~ /class="loginlist visible">.*?<strong>([^<]*)</si;
  unless ($login){
    open my $w, '>logins.html';
    print $w $html;
    close $w;
    die "cannot parse login list (see logins.html)";
  }
  return $login;
}


sub save_to_db {
  my $self = shift;
  my $ip = shift || '';
  my $dbh = DBI->connect("dbi:mysql:seo", 'lavan', 'Gh2mooK6C');
  $dbh->do("
    insert into yandex_accounts (login, password, ip) values (?, ?, ?)
  ", {}, $self->login, 'shkola91', $ip);
  $dbh->disconnect;
}


sub _create_login($$) {
  my ($iname, $fname) = @_;
  my $line = $iname . " " . $fname;
  my $login = lc $line;
  $login =~ tr/ �������������������������������/.abvgdeejzijklmnoprstufhc4wwe77uy/;
  $login =~ s{y}{ja};
#  $login .= ".dr";
  return $login; 
}


sub rand_iname {
  return '����';
} # TODO:

sub rand_fname {
  return '������';
} # TODO:

sub fetch_person {
  open my $r, 'base.txt';
  my $line = <$r>;
  $line = $1 if $line =~ /.*?,"(.*)"]/;
  
  my $rest_text = '';
  while(<$r>){
    $rest_text .= $_;
  }
  close $r;
  open my $w, ">base2.txt";
  print $w $rest_text;
  close $w;
  
  my ($iname, $fname) = split / /, $line;
  return($iname, $fname);
} # ����� ������� ��������� ���-������� �� ����� ��� �����


1;