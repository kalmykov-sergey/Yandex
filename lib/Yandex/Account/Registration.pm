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

=pod

  #!/usr/bin/perl -w

  use CGI qw(:standard);
  use Yandex::Account::Registration;

  my $msg;
  if(my $filename = param('store')){
    my $code = param('code');
    my $reg = Yandex::Account::Registration->new({}, $filename);
    if (my $ok = $reg->send_captcha($code)){
      $msg = "Success!";
    }
  }

  my $reg = Yandex::Account::Registration->new();
  my $src = $reg->get_captcha();
  my $filename = $reg->{store};

  print header(-type => 'text/html', -charset => 'cp1251'),
    h1("Lets register ".$reg->{iname}. " ". $reg->{fname}),
    h3($msg),
    start_form, 
    img({src => $src}), 
    textfield('code'), 
    hidden('store', $filename),
    submit, 
    end_form;

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
    $self->{login} = $stored->{login};
    $self->{password} = $stored->{password};
  } else {
    $self->{ua}->get('http://xml.yandex.ru'); # для куков
  }

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
  my $login = _create_login($self->{iname}, $self->{fname});

  my $form1 = HTML::Form->parse($resp1);
  $form1->value(iname => $self->{iname});
  $form1->value(fname => $self->{fname});
  $form1->value(login => $login);
  my $resp2 = $self->{ua}->request($form1->click);
  die $resp2->status_line unless $resp2->is_success;

  if($resp2->content =~ m{class="loginlist visible"}){ # список доступных логинов
    # создаем валидный (для Яндекса) логин 
    $login = _parse_yandex_logins($resp2->content);
    $form1 = HTML::Form->parse($resp2);
    $form1->value(iname => $self->{iname});
    $form1->value(fname => $self->{fname});

    # отсылаем форму с нормальным логином
    $form1->value(login => $login);
    $resp2 = $self->{ua}->request($form1->click);
  } else {
    # такого логина нет, т.е. можно регистрировать дальше
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
  $self->{ua}->get($src); # ЭТО ОЧЕНЬ ВАЖНО, ИНАЧЕ РЕГИСТРАЦИЯ НЕ ПРОЙДЕТ
  unless($src){
    open my $w, '>whereiscaptcha.html';
    print $w $html;
    close $w;
    die "не нашли адреса капчи"; 
  }

  # сохраняем объект в файле $rand_file_name
  my $rand_file_name = md5_hex($self) . '.storable';
  $self->{resp2} = $resp2;
  $self->{store} = $rand_file_name;
  $self->{src} = $src;
#  die Dumper $self;

  $self->{password} = 'shkola91'; # вообще лучше генерить случайные

  my $form2 = HTML::Form->parse($resp2);
  $form2->value(passwd => $self->{password}); 
  $form2->value(passwd2 => $self->{password});
  $form2->value(hintq => 3); # правильнее случайное целое от 0 до 5
  $form2->value(hinta => 'I have no dog'); # а здесь ответ на секретный вопрос

  $Storable::Deparse = 1;
  store {
    login => $self->{login},
    password => $self->{password},
    form => $form2, 
    cookie_jar => $self->{ua}->cookie_jar
  }, $rand_file_name;
 
  return $src;
}


sub send_captcha {
  my $self = shift;
  my $code = shift;

  my $form2 = $self->{form2};
  $form2->value(code => $code);
  
  my $req = $form2->click;
  $self->{ua}->prepare_request($req);
  my $resp3 = $self->{ua}->request($req);

  my $html = encode('cp1251', decode('utf-8', $resp3->content));

  if($html =~ /Вы неправильно ввели контрольные цифры./){
    unlink $self->{store} if $self->{store};
    return 0;
  }
  if($html =~ /Ошибка обработки запроса/){
    die "bad request (?):\n", Dumper ($req);
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

  open my $a, '>>logins.log';
  print $a $self->{login}, "\t", $self->{password}, "\n"; 
  close $a;

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


sub _create_login($$) {
  my ($iname, $fname) = @_;
  my $line = $iname . " " . $fname;
  my $login = lc $line;
  $login =~ tr/ абвгдеёжзийклмнопрстуфхцчшщэьъюя/.abvgdeejzijklmnoprstufhc4wwe77uy/;
  $login =~ s{y}{ja};
#  $login .= ".dr";
  return $login; 
}


my $dir = __FILE__;
$dir =~ s{/Registration\.pm}{};


sub rand_iname {
  open my $r, "<$dir/inames.txt";
  chomp(my @names = <$r>);
  close $r;
  return $names[int rand($#names)];
}


sub rand_fname {
  open my $r, "$dir/fnames.txt";
  chomp(my @names = <$r>);
  close $r;
  return $names[int rand($#names)];
}


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