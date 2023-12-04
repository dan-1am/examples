#!/usr/bin/perl

#version 1.06

use POSIX qw/round/;
use Encode ();

my %vars;
my $oswindows=$^O=~/Win32/;

if(!$oswindows){
#  binmode(STDOUT, ":utf8");
}


sub sysfname{ my ($fname)=@_;
# decode
  my $sysname=$fname;
  if($oswindows){
    Encode::from_to($sysname, "UTF-8", "cp1251");
  }
#print "Open $fname=[$sysname]...\n";
  return $sysname;
}



sub readfile{ my ($fname)=@_;
  my $sname=sysfname($fname);
  die "Error: can not open file [$fname]" unless(open my $fh,'<',$sname);
  binmode $fh, ":crlf";
  local $/ = undef;
  my $t=<$fh>;
  close $fh;
  return $t;
}


sub writefile{ my ($fname,$txt)=@_;
  my $sname=sysfname($fname);
  die "Error: can not create file [$fname]" unless(open my $fh,'>',$sname);
  binmode $fh, ":crlf";
  print{$fh} $txt;
  close $fh;
}


sub round01{my ($n)=@_;
  my $r=sprintf "%.2f",round($n*100)/100;
  return $r eq "-0.00" ? "0.00" : $r;
}


sub roundn{my ($digits,$n)=@_;
  my $m=10**$digits;
  my $r=sprintf "%.${digits}f",round($n*$m)/$m;
  return $r eq substr("-0.0000000000000000",0,3+$digits) ? substr($r,1) : $r;
}



#********************** say number ****************************

sub saynum9{my ($n,$fem)=@_;
  return "" if($n==0);
  return $n==1 ? "одна " : "две " if($fem and $n<3);
  return (split/,/,",один ,два ,три ,четыре ,пять "
  . ",шесть ,семь ,восемь ,девять ")[$n];
}


sub saynum99{my ($n,$fem)=@_;
  if($n>10 and $n<20){
    return (split/,/,"одиннадцать ,двенадцать ,тринадцать "
    . ",четырнадцать ,пятнадцать ,шестнадцать ,семнадцать "
    . ",восемнадцать ,девятнадцать ")[$n-11];}
  my $r="";
  if($n>9){
    $r=(split/,/,"десять ,двадцать ,тридцать ,сорок ,пятьдесят "
    . ",шестьдесят ,семьдесят ,восемьдесят ,девяносто ")[int($n/10)-1];
    $n=$n%10;
  }
  return $r.saynum9($n,$fem);
}  


sub saynum100{my ($n)=@_;
  return (split/,/,",сто ,двести ,триста ,четыреста ,пятьсот "
    . ",шестьсот ,семьсот ,восемьсот ,девятьсот ")[$n];
}


sub saynumtail{my ($n,@t)=@_;
  $n=$n%100;
  return $t[2] if($n>9 and $n<20);
  $n=$n%10;
  return $n==1 ? $t[0] : (($n and $n<5) ? $t[1] : $t[2]);
}


sub saynum999{my ($n,$fem,@t)=@_;
  return saynum100(int($n/100)).saynum99($n%100,$fem).saynumtail($n,@t);
}


sub saynumber{my ($n,$fem,@gr0)=@_;
  return "ноль ".$gr0[2] if($n==0);
  my @grs=([@gr0]
  , ["тысяча ","тысячи ","тысяч "]
  , ["миллион ","миллиона ","миллионов "]
  , ["миллиард ","миллиарда ","миллиардов "]
  , ["триллион ","триллиона ","триллионов "]
  , ["квадриллион ","квадриллиона ","квадриллионов "]
  , ["квинтиллион ","квинтиллиона ","квинтиллионов "]);
  my $r=$n<0 ? "минус " : "";
  $n=abs($n);
  $n=substr("00",(2+length($n))%3).$n;
  my $gr=int((length($n)-1)/3);
  while($gr>=0){
    $r.=saynum999(substr($n,0,3), ($gr==1 or $gr==0 and $fem), @{$grs[$gr]});
    $n=substr($n,3);
    --$gr;
  }
  return $r;
}


sub saymoney{my ($n)=@_;
  my $kop=substr(int(abs($n)*100+100.5),-2);
  my $rub=$n<0 ? -int(-$n) : int($n);
  return saynumber($rub,0,"рубль, ","рубля, ","рублей, ")
  .$kop.saynumtail($kop," копейка"," копейки"," копеек");
}



#********************** dates *********************************

sub dateprefix{my ($d)=@_;
  return substr($d,2,2).substr($d,5,2).substr($d,8,2)."_";}

sub monthdays{my ($y,$m)=@_;
  if(not $m){
    $y=~/^(\d{4})\.(\d\d)/;
    ($y,$m)=($1,$2);
  }
  if($m==2){
#    $d=$y%4 ? 28 : 29; #!!! to refine!
    if($y%400==0){
      $d=29;
    }elsif($y%100==0){
      $d=28;
    }elsif($y%4==0){
      $d=29;
    }else{
      $d=28;
    }
  }else{
    $d=(0,31,28,31,30,31,30,31,31,30,31,30,31)[$m];
  }
  return $d;
}

sub lastday{my ($d)=@_;
  $d=~/^(\d{4})\.(\d\d)/;
  my ($y,$m)=($1,$2);
  if($m==2){
#    $d=$y%4 ? 28 : 29; #!!! to refine!
    if($y%400){
      $d=29;
    }elsif($y%100){
      $d=28;
    }elsif($y%4){
      $d=29;
    }else{
      $d=28;
    }
  }else{
    $d=(0,31,28,31,30,31,30,31,31,30,31,30,31)[$m];
  }
  return "$y.$m.$d";
}

sub prevday{my ($d)=@_;
  my ($y2,$m2,$d2)=(substr($d,0,4),substr($d,5,2),substr($d,8,2));
  if(--$d2<1){
    if(--$m2<1){
      --$y2;
      $m2=$m2+12;
    }
    $d2+=monthdays($y2,$m2);
  }
  return sprintf("%04d.%02d.%02d",$y2,$m2,$d2);
}

sub nextmonth{my ($m)=@_;
  my ($y2,$m2)=(substr($m,0,4),substr($m,5,2)+1);
  $m2=$m2-12, ++$y2 if($m2>12);
  return $y2.".".($m2<10 ? "0$m2" : $m2);
}

sub prevmonth{my ($m)=@_;
  my ($y2,$m2)=(substr($m,0,4),substr($m,5,2)-1);
  if($m2<1){
    $m2=$m2+12;
    --$y2;
  }
  return $y2.".".($m2<10 ? "0$m2" : $m2);
}

my @mnames1=(qw/0 январь февраль март апрель май июнь июль август сентябрь/,
  qw/октябрь ноябрь декабрь/);

sub saymonth{my ($d)=@_;
  my $m=substr($d,5,2);
  return $mnames1[$m]." ".substr($d,0,4)."&nbsp;г.";
}

my @mnames2=(qw/0 января февраля марта апреля мая июня июля августа сентября/,
  qw/октября ноября декабря/);

sub saydate{my ($d)=@_;
  my $m=substr($d,5,2);
  return substr($d,8,2)." ".$mnames2[$m]." ".substr($d,0,4)."&nbsp;г.";
}



#********************** commands ******************************

my %v;

#sub setvars{my ($t)=@_; $v{$1}=$2 while $t=~/^(\w+)=(.*?)(\s*\#.*)?$/gm;}

sub expandvars{my ($txt)=@_;
  $txt=~s/\$\{(\w+)\}/$v{$1}/ge;
  $txt=~s/\$\{(\w+)\}/$v{$1}/ge; #!!! todo: loop while no changes
  return $txt;
}

sub process{my ($lines)=@_;
  my $sub='';
  my $body;
  for( split/\n/,$lines ){
    s/\s*\#.*//s;
    s/^\s+//;
    if( /^sub\s+(\w+)$/s ){
      $sub=$1;
      $body='';
      next;
    }
    if($sub ne ''){
      if( /^endsub\s*$/s ){
        $v{'subs'}{$sub}=$body;
        $sub='';
      }else{
        $body.=$_."\n";
      }
      next;
    }
    $_=expandvars($_);
    if( /^(\w+)=(.*)$/s ){
      $v{$1}=$2;
    }elsif( /^(\w+)\s*?(\s(\S.*))?$/s ){
      &callsub($1,$3)
    }elsif( not /^\s*$/ ){
      die "Error in process line: $_"
    }
  }
}


sub callsub{my ($name,$arg)=@_;
  if( $v{'subs'}{$name} ne '' ){
    $v{'arg'}=$arg;
    process( $v{'subs'}{$name} );
  }else{
    my $sub = \&{$name};
    $v{"ret"}=$sub->($arg);
  }
}


sub splitarg{my ($t)=@_;
  @v{split/\,/,$t}=split/\,/,$v{'arg'};
}


sub callargs{my ($t)=@_;
  my ($sub,@a)=split/,/,$t;
  $sub=\&{$sub};
  $v{"ret"}=$sub->(@a);
}


sub foreach{my ($t)=@_;
  my ($sub,@a)=split/,/,$t;
  for(@a){
    callsub($sub,$_);
  }
}


sub dofile{my ($fname)=@_;
  my $t=readfile($fname);
  process($t);
}


sub evaluate{my ($t)=@_;
  return eval $t;
}


sub clearlist{my ($l)=@_;
  @{ $v{$l} }=();
}


sub poplist{my ($l)=@_;
  return pop @{ $v{$l} };
}


sub pushlist{my ($a)=@_;
  my ($to,@from)=split/\s*\,\s*/,$a;
  push @{$v{$to}},@{ $v{$_} } for(@from);
}


sub pushdoc{my ($l)=@_;
  push @{$v{$l}}, {
    date=>$v{"date"},
    sum=>$v{"total"},
    name=>$v{"docname"},
    fname=>$v{"filename"},
  };
}


sub pushinfo{my ($a)=@_;
  my $l;
  ($l,@v{qw/date total docname filename/})=split/\s*\,\s*/,$a,5;
  pushdoc($l);
}


sub pushfile{my ($a)=@_;
  my ($l,$fname)=split/\s*\,\s*/,$a,2;
  if($fname=~/^(\d\d)(\d\d)(\d\d)\_(\D+?)(\d+.*?)?\_.*?\_(\-?\d+\.\d+)\.\w+$/){
    my $d="20$1.$2.$3";
    @v{qw/date total docname filename/}=($d,$6,"$4 $5",$fname);
  }else{
    die "Error! Wrong file name format in pushfile: $fname";
  }
  pushdoc($l);
}


sub pushvar{ my ($a)=@_;
  my ($l,$var)=split/\s*\,\s*/,$a,2;
  push @{ $v{$l} },$v{$var};
}


sub popvar{ my ($a)=@_;
  my ($arr,@vars)=split/\s*\,\s*/,$a;
  for(@vars){
    $v{$_}=pop @{ $v{$arr} };
  }
}


sub docsbetween{my ($a)=@_;
  my ($l,$d1,$d2)=split/\s*\,\s*/,$a;
  $d1="0000.00.00" unless($d1);
  $d2="9999.99.99" unless($d2);
  $v{$l}=[ grep{ $_->{"date"} ge $d1 and $_->{"date"} le $d2 } @{ $v{$l} } ];
}


sub sumdocs{my ($a)=@_;
  my (@l)=split/\s*\,\s*/,$a;
  my $s=0;
  for(@l){
    for( @{ $v{$_} } ){
      $s+=$_->{"sum"};
    }
  }
  return $v{"total"}=round01($s);
}


sub makedoc{
  $v{"docname"}=$v{"doctype"}." ".$v{"docnum"};
  $v{"filename"}=dateprefix($v{"date"}).$v{"doctype"}.$v{"docnum"}."_".
    $v{"nameextra"}."_".$v{"total"}.".htm";
  pushdoc("alldocs");
  if( $v{"write"} ){
    my $form = readfile($v{"form"});
    $form=expandvars($form);
    my $fname=$v{'writedir'}.$v{'filename'};
    mkdir $v{'writedir'} unless(-d $v{'writedir'});
    print "writing [$fname]...\n";
    writefile($fname,$form);
  }
}



my @tbl_align;

sub table_align{@tbl_align=@_;}

sub table_head{my @d=@_;
  my $t="<tr class='table_head'>\n";
  for(0..$#d){
    my $c=$tbl_align[$_];
    $c=$c ? " class='".$c."'" : "";
    $t.="<td$c>".$d[$_]."</td>\n";
  }
  $v{"table"}=$t."</tr>\n";
}

sub table_row{my @d=@_;
  my $t="<tr>\n";
  for(0..$#d){
    my $c=$tbl_align[$_];
    $c=$c ? " class='".$c."'" : "";
    $t.="<td$c>".$d[$_]."</td>\n";
  }
  $v{"table"}.=$t."</tr>\n";
}





#********************** dogovor actions ***********************

sub set_date{my ($d)=@_;
  @v{qw/date saydate/}=($d,saydate($d));
}


sub set_month{my ($m)=@_;
#  set_date( lastday($m) );
  set_date($m);
  $v{"saymonth"}=saymonth($m);
  $v{"sayday1"}=saydate( substr($m,0,7) . ".01" );
}


sub waresum{my ($c,$p)=@_;return round01( eval($c)*eval($p) )};


sub ndssum{my ($ware)=@_;
  my $b=$v{$ware."base"}=round01($v{$ware}*$v{$ware."price"});
  my $ndsp=$v{$ware."ndspercent"};
  $ndsp=0 if( not $ndsp > 0 );
  my $n=$v{$ware."nds"}=round01($b*$ndsp/100);
  $v{$ware."sum"}=round01($b+$n);
}


sub count_sums{my (@wares)=@_;
  for(@wares){
    ndssum($_);
  }
}


sub addwares{my ($a)=@_;
  my ($list,@wares)=split/\s*\,\s*/,$a;
  count_sums(@wares);
  for my $w (@wares){
    push @{ $v{$list} },{
      id=>$w,
      text=>$v{$w.'text'}.( $v{'ware_add_date'} ? ", ".$v{'saymonth'} : "" ),
      unit=>$v{$w.'unit'},
      count=>$v{$w},
      price=>$v{$w.'price'},
      ndspercent=>$v{$w.'ndspercent'},
      nds=>$v{$w.'nds'},
      sum=>$v{$w.'sum'},
    };
  }
}


sub logwares{my ($list)=@_;
  for(@{ $v{$list} }){
    print join(",",@v{qw/date doctype docnum/},@{$_}{qw/sum text/}),"\n";
  }
}


sub printwares{my ($list)=@_;
  $v{"total"}=0;
  $v{"ndstotal"}=0;
  if( $v{"shownds"} ){
    table_align("tacenter", "taleft widecell", qw/tacenter taright taright taright taright/);
    my $ndshead="НДС&nbsp;".$v{"enrndspercent"}."%, руб."; #!!! todo: move to config
    table_head("№","Наименование","Ед.","Кол-во",
      "Цена, руб.",$ndshead,"Сумма, руб.");
  }else{
    table_align("tacenter", "taleft widecell", qw/tacenter taright taright taright/);
    table_head("№","Наименование","Ед.","Кол-во",
      "Цена, руб.","Сумма, руб.");
  }
  my $i=0;
  for my $w (@{ $v{$list} }){
    if( $v{"shownds"} ){
      table_row( ++$i, @{$w}{qw/text unit count price nds sum/} );
    }else{
      my $price=$w->{'price'};
      if( $w->{ 'ndspercent' } > 0 ){
        $price.="*1.".$w->{'ndspercent'};
      }
      table_row(++$i,@{$w}{qw/text unit count/},$price,$w->{'sum'});
    }
    $v{"total"}+=$w->{'sum'};
    $v{"ndstotal"}+=$w->{'nds'};
  }
  $v{'warescount'}=$i;
  $v{'total'}=round01($v{'total'});
  $v{'ndstotal'}=round01($v{'ndstotal'});
  table_row("","Всего","","","", ( $v{'shownds'} ? ($v{"ndstotal"}) : () ), $v{'total'});
  $v{"saytotal"}=saymoney($v{"total"});
  return $v{"warestable"}=$v{"table"};
}


sub doctable{my ($a)=@_;
  my (@l)=split/\s*\,\s*/,$a;
#  table_align(qw/tacenter tacenter taright taleft/);
  table_align(qw/tacenter taleft tacenter taright/);
#  table_head("№","Дата","Сумма","Документ");
  table_head("№","Документ","Дата","Сумма");
  my $i=0;
  for(@l){
    for( @{ $v{$_} } ){
      my ($file,@doc)=@{$_}{qw/fname name date sum/};
      if($file eq "head"){
        table_row("",map{"<b>$_</b>"}@doc);
      }else{
        table_row(++$i,@doc);
      }
    }
  }
  return $v{"doctable"}=$v{"table"};
}


sub println{my ($l)=@_;
  $l=~s/\\n/\n/g;
  print $l;
}


sub printlist{my ($l)=@_;
  for(@{ $v{$l} }){
    print join("\t",@{$_}{qw/date sum name fname/}),"\n";
  }
}



#********************** processing ****************************

#/*border-collapse:separate => IE bug: border-spacing=2 always*/
#table.table_data {width: 100%; border-collapse: collapse; border: 2px solid;}

#process(<<'End');
#dofile autobill.dat
#End

dofile("autobill.dat");
