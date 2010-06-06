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

  if($file_to_retrieve){
    return retrieve($file_to_retrieve);
  }

  my $ua = LWP::UserAgent->new(
    agent => 'Mozilla 5.0 (MSIE 9.0)',
    requests_redirectable => ['GET', 'POST'],
  );
  $ua->cookie_jar({
    #file => 'cookies.lwp', 
    #autosave => 1
  });
  $ua->get('http://xml.yandex.ru'); # для куков

  my $iname = $hash_ref->{iname} || rand_iname();
  my $fname = $hash_ref->{fname} || rand_fname();

  my $self = {ua => $ua, iname => $iname, fname => $fname};
  bless $self, $class;
  return $self;
}


sub _step1 {
  my $self = shift;
  my $resp1 = $self->{ua}->get(
    'http://passport.yandex.ru/passport?mode=register&retpath=http://xml.yandex.ru/'
  );
  die $resp1->status_line unless $resp1->is_success;

  # отсылаем сначала форму с уже существующим логином, 
  # чтобы получить подсказку - список доступных логинов
  my $form1 = HTML::Form->parse($resp1);
  $form1->value(iname => $self->{iname});
  $form1->value(fname => $self->{fname});
  $form1->value(login => 'a');
  my $login_list_resp = $self->{ua}->request($form1->click);
  # $login_list_resp->content =~ m{class="loginlist visible"};
  
  # создаем валидный (для Яндекса) логин 
  my $login = _parse_yandex_logins($login_list_resp);
  $login = _create_login($self->{iname}, $self->{fname}) unless $login;

  # отсылаем форму с нормальным логином
  $self->{login} = $login;
  $form1->value(login => $login);
  my $resp2 = $self->{ua}->request($form1->click);
  die $resp2->status_line unless $resp2->is_success;

  return $resp2;
}


sub get_captcha {
  my $self = shift;
  my $resp2 = $self->_step1;
  die $resp2->status_line unless $resp2->is_success;
  my $html = $resp2->content;
  open my $w, '>resp2.html';
  print $w $html;
  close $w;

  my $src = $1 if $html =~ m{class="captcha-img" src="([^"]*)"};
  die "не нашли адреса капчи" unless $src;

  # сохраняем объект в файле $rand_file_name
  my $rand_file_name = md5_hex($self);
  $self->{resp2} = $resp2;
  $self->{store} = $rand_file_name;
  $self->{src} = $src;
  store $self, $rand_file_name;

  return $src;
}


sub send_captcha {
  my $self = shift;
  my $code = shift;

  my $resp2 = $self->{resp2};
  my $form2 = HTML::Form->parse($resp2);
  $form2->value(passwd => 'shkola91'); # вообще лучше генерить случайные
  $form2->value(passwd2 => 'shkola91');
  $form2->value(hintq => 3); # правильнее случайное целое от 0 до 5
  $form2->value(hinta => 'Жучка'); # а здесь ответ на секретный вопрос
  $form2->value(code => $code);
  
  my $req = $form2->click;
  $self->{ua}->prepare_request($req);
  #die Dumper($req);
  my $resp3 = $self->{ua}->request($req);

  my $html = encode('cp1251', decode('utf-8', $resp3->content));

  if($html =~ /Вы неправильно ввели контрольные цифры./){
    return 0;
  }
  if($html =~ /\(Cookies\)/){
    die $req->as_string, "\nнеобходимо включить куки (Cookies)";
  }
  unless($html =~ /Поздравляем/){
    open my $w, '>resp3.html';
    print $w $html;
    close $w;
    die "неизвестная ошибка";
  }
  
  $self->{ua}->get('http://passport.yandex.ru/passport?mode=logout'); # для очистки куков
  unlink $self->{store} if $self->{store};
  return 1;
}


sub _parse_yandex_logins {
  my $resp = shift;
  open my $w, '>resp_logins.html';
  print $w $resp->content;
  close $w;
  # TODO:
  return;
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
  $login =~ tr/ абвгдеёжзийклмнопрстуфхцчшщэьъюя/.abvgdeejzijklmnoprstufhc4wwe77uy/;
  $login =~ s{y}{ja};
  $login .= ".dr";
  return $login; 
}


sub rand_iname {
  return 'Вася';
} # TODO:

sub rand_fname {
  return 'Пупкин';
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
} # можно сделать случайные имя-фамилию из файла как здесь


1;