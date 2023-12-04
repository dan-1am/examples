#!/usr/bin/perl

use Digest::MD5 qw/md5_base64/;

my $confdir="$ENV{HOME}/.config/newsdir";
my $datadir=$confdir;
my $confname="$confdir/newsdir.conf";


my %entities=(
  quot=>'"',
  amp=>'&',
  apos=>"'",
  lt=>'<',
  gt=>'>',
# html5:
  excl=>'!',
  num=>'#',
  dollar=>'$',
  percent=>'%',
  lpar=>'(',
  rpar=>')',
  ast=>'*',
  midast=>'*',
  plus=>'+',
  comma=>',',
  period=>'.',
  sol=>'/',
  colon=>':',
  semi=>';',
  equals=>'=',
  quest=>'?',
  commat=>'@',
  lsqb=>'[',
  lbrack=>'[',
  bsol=>"\\",
  rsqb=>']',
  rbrack=>']',
  Hat=>'^',
  lowbar=>'_',
  Underbar=>'_',
  grave=>'`',
  lcub=>'{',
  lbrace=>'{',
  verbar=>'|',
  vert=>'|',
  nbsp=>' ',
  cent=>'¢',
  pound=>'£',
  curren=>'¤',
  yen=>'¥',
  brvbar=>'¦',
  sect=>'§',
  copy=>'©',
  laquo=>'«',
  reg=>'®',
  circledR=>'®',
  deg=>'°',
  plusmn=>'±',
  pm=>'±',
  sup2=>'²',
  sup3=>'³',
  acute=>'´',
  micro=>'µ',
  para=>'¶',
  middot=>'·',
  centerdot=>'·',
  sup1=>'¹',
  ordm=>'º',
  raquo=>'»',
  frac14=>'¼',
  frac12=>'½',
  half=>'½',
  frac34=>'¾',
  times=>'×',
  Oslash=>'Ø',
  divide=>'÷',
  div=>'÷',
  oslash=>'ø',
  fnof=>'ƒ',
  circ=>'ˆ',
  ring=>'˚',
  tilde=>'˜',
  hyphen=>'‐',
  dash=>'‐',
  ndash=>'–',
  mdash=>'—',
  horbar=>'―',
  Verbar=>'‖',
  Vert=>'‖',
  lsquo=>"‘",
  rsquo=>"’",
  rsquor=>"‘",
  sbquo=>"‚",
  lsquor=>"‚",
  ldquo=>'“',
  rdquo=>'”',
  rdquor=>'”',
  bdquo=>'„',
  ldquor=>'„',
  dagger=>'†',
  ddagger=>'‡',
  bull=>'•',
  bullet=>'•',
  hellip=>'…',
  mldr=>'…',
  frasl=>'⁄',
  euro=>'€',
);

sub parsetext{ my ($text)=@_;
  $text=~s/\<\!\[CDATA\[(.*?)\]\]\>/$1/sg;
  $text=~s/\<p\>\s*(.*?)\s*\<\/p\>/$1\n/sg;
  $text=~s|\<br\/?\>|\n|g;
  $text=~s/[ \r\t]+$//mg;
  $text=~s/\n\n\n+/\n\n/sg;
  for( keys %entities ){
    $text=~s/\&$_\;/$entities{$_}/g;
  }
  return $text;
}

sub escapename{ my ($name)=@_;
  $name=~tr|/\n|__|;
  return $name;
}

sub hostname{ my ($url)=@_;
  $url=~s|^\w+\:\/\/||;
  $url=~m|^([^\/]*)|;
  return $1;
}

my %months=(
  Jan=>"01",
  Feb=>"02",
  Mar=>"03",
  Apr=>"04",
  May=>"05",
  Jun=>"06",
  Jul=>"07",
  Aug=>"08",
  Sep=>"09",
  Oct=>"10",
  Nov=>"11",
  Dec=>"12",
);

sub rssdate{ my ($time)=@_;
  $time=~/(\d\d)\s+(\w+)\s+(\d\d)?(\d\d)\s+(\d\d)\:(\d\d)\:(\d\d)/;
  return $4.$months{$2}.$1.$5.$6;
}

sub nowdate{
  my ($s,$m,$h,$dd,$mm,$yy)=localtime();
  return sprintf "%d%02d%02d%02d%02d",substr(1900+$yy,2),$mm,$dd,$h,$m;
}

sub readtags{ my ($src,@words)=@_;
  my %tags;
  for( @words ){
    $src=~/\<$_(\s+\S.*?)??\>\s*(.*?)\s*\<\/$_\>/s;
    $tags{$_}=$2;
  }
  return %tags;
}

sub loadconf{ my ($file)=@_;
  my %data=(del_empty_lines=>1, list=>{});
  unless(-e $file){
    return %data;
  }
  die "Error: can not open file $file" unless open my $fh,'<',$file;
  my $mode=0;
  while(<$fh>){
    chomp;
    if($mode){
      my ($hash,$title)=split/\s+/,$_,2;
      $data{'list'}{$hash}=$title;
    }elsif(/^\s*(\w+)\s*\=\s*(.*?)$/){
      if($1 eq "list"){
        $mode=1;
      }else{
        $data{$1}=$2;
      }
    }
  }
  close $fh;
  return %data;
}


sub saveconf{ my ($file,%data)=@_;
  die "Error: can not write to file $file" unless open my $fh,'>',$file;
  my $list=$data{'list'};
  my @order=sort{$list->{$a} cmp $list->{$b}} keys %$list;
  $list=join("\n", map{$_." ".$list->{$_}} @order);
  delete $data{'list'};
  for(sort keys %data){
    print{$fh} "$_=",$data{$_},"\n";
  }
  print{$fh} "list=\n$list\n";
  close $fh;
}


sub loadfeed{ my ($feed)=@_;
#print "url=$feed\n";
  my $page=`curl -s $feed`;
  if($?){
    die "Error: can not load feed $feed";
  }
  my @items=split /\<item\>/,$page;
  my %head=readtags(shift @items, qw/title link description pubDate/);
  my $chadir=hostname($feed)." ".escapename( $head{'title'} );
  my $path="$datadir/$chadir";
  if(not -d $path){
    return "error" unless mkdir $path;
  }
  my $date0 = $head{'pubDate'} ne "" ? rssdate($head{'pubDate'}) : nowdate();
print "#### channel=$chadir\n";
  my $conffile="$path/.newsdir";
  my %conf=loadconf($conffile);
  my %loaded;
  my $new=0;
  for(@items){
    my %item=readtags($_, qw/title link description guid pubDate/);
#print "item=[",$item{'title'},"\n",$item{'pubDate'},"\n",
#$item{'link'},"\n",$item{'description'},"]\n";
    my $hash=md5_base64($item{'title'}.$item{'description'});
    $loaded{$hash}=1;
    if(not exists $conf{'list'}{$hash}){
      ++$new;
      $_=parsetext($_) for(@item{qw/title description/});
print $item{'title'},"\n";
      my $date= $item{'pubDate'} ne "" ? rssdate($item{'pubDate'}) : $date0;
      my $fname="$date-".$item{'title'};
      $conf{'list'}{$hash}=$fname;
      my $file="$path/".escapename($fname).".txt";
      die "Error: can not write to file $file" unless open my $out,'>',$file;
      print {$out} $item{'title'},"\n",$item{'link'},"\n",
        $item{'pubDate'},"\n",$item{'description'};
      close $out;
    }
  }
print "$new / ",0+@items," loaded.\n";
  for( keys %{$conf{'list'}} ){
    delete $conf{'list'}{$_} if( not $loaded{$_} );
  }
  saveconf($conffile,%conf);
}



die "Error: no file $confname" unless open my $conf,'<',$confname;
mkdir $datadir;
while(<$conf>){
  loadfeed($_) if( substr($_,0,1) ne '#' );
}
close $conf;
