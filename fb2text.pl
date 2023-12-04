#!/usr/bin/perl

#fb2text.pl
#2010.05.12 02:01:25 v1.04 UtfChars: '--'
#2009.12.04 00:41:50 v1.03 -param: -cp=page
#2009.10.08 20:55:05 v1.02 -binary section skip
#2009.07.21 04:49:23 v1.01 -encodings support
#2009.07.20 22:12:29 v1.00


use Encode;
my $target_cp="cp1251";
my $source_cp=$target_cp;
my $encode_cp=($source_cp eq $target_cp)? 0 : 1 ;

my @xml=({tag=>'_none_',chars=>0});
my @level;
my @structure=('_base_');


sub OutWarn{
  print "[Warning: ",@_,"]";
}



############################### Chars #########################

sub UtfChars($){ my $txt=shift;
  $txt=~s/\xE2\x80\x95/--/g;
  return $txt;
}


sub GoodChars($){ my $txt=shift;
  for($txt){
    s/\xAB/\<\</g;           #угловые кавычки
    s/\xBB/\>\>/g;           #угловые кавычки
    s/\x84/,,/g;             #кавычки
    s/\x93/``/g;             #кавычки
    s/\x94/''/g;             #кавычки

    s/\x96/-/g;              #среднее тире (между частями предложения)
    s/\x97/\-\-/g;           #длинное тире (начало диалога)

    s/\x85/.../g;            #многоточие
#  s/\x92/'/g;
    s/\xAD//g;	           #мягкий перенос
    s/\xA0/ /g;              #shift+space (неразрывный пробел)
    s/\xA9/(c)/g;            #Copyright

    s/amp;/&/g;
    s/&quot;/"/g;
  }
  return $txt;
}



############################### Tags ##########################

my %structures=(
  section=>1,
  epigraph=>1,
  annotation=>1,
  history=>1,
);


my %tag_style=(
  fictionbook=>{},
  description=>{start=>("*"x64)."\n", end=>"\n"},
    'title-info'=>{start=>"#### Title info:\n", end=>"\n"},
    'document-info'=>{start=>"#### Document info:\n",end=>"\n"},
    'publish-info'=>{start=>"#### Publish info:\n",end=>"\n"},
      'book-title'=>{start=>"Title: ", end=>"\n"},
      author=>{start=>"Author:", end=>"\n"},
      'first-name'=>{start=>" "},
      'middle-name'=>{start=>" "},
      'last-name'=>{start=>" "},
      nickname=>{start=>" <<", end=>">>"},
      email=>{start=>" "},
      annotation=>{start=>"Annotation:\n"},
      history=>{start=>"History:\n"},
  body=>{start=>("*"x64)."\n", end=>"\n"},
    section=>{end=>"\n"},
      title=>{end=>"\n"},
      epigraph=>{start=>"Epigraph:\n", end=>"\n"},
        'text-author'=>{start=>"<<", end=>">>\n"},
      subtitle=>{start=>"\n###### ", end=>"\n"},
      p=>{start=>"", end=>"\n"},
        emphasis=>{start=>"</", end=>"/>"},
        strong=>{start=>"<^", end=>"^>"},
        a=>{},
      poem=>{start=>"\n",end=>"\n"},
        v=>{start=>"    ", end=>"\n"},
  binary=>{start=>("*"x64)."\nBinary:", end=>"\n", skip=>1},
);

our $skipcounter;

sub SelfClosedTag($){ my $tag=shift;
  if($tag eq 'empty-line'){
    print "\n";
  }else{
    OutWarn "unknown <$tag/>";
  }
}


sub OpenTag($){ my $tag=shift;
  if( $tag=~ m{^(.+)/$} ){
    SelfClosedTag($1);
    return;
  }
  my $params;
  if( $tag=~ /^(.+?)\s(.+)$/ ){
    $tag=$1;
    $params=$2;
#    OutWarn "params <",$tag,">";
  }
  ++$skipcounter if $tag_style{$tag}{'skip'};
  print $tag_style{$tag}{'start'} if defined $tag_style{$tag};
  if($tag eq 'section'){
    $level[$#level]++;
    if(@level){
      print "###### ";
      print $_,"." for(@level);
    }
    print "\n";
    push @level,0;
  }elsif($tag eq 'body'){
    push @level,0;
#    if($params=~/name\=\"notes\"/){
#    }
  }elsif($tag eq '?xml'){
    $params=~/encoding\=(\"?)(\S+)\1\??/;
    $source_cp=$2;
    unless($target_cp){
      $target_cp=$source_cp;
      $encode_cp=0;
    }elsif(Encode::resolve_alias($source_cp) eq Encode::resolve_alias($target_cp)){
      $target_cp=$source_cp;
      $encode_cp=0;
    }else{
      $encode_cp=1;
    }
    return;
  }

  if($structures{$tag}){
    push @structure,$tag;
  }
  push @xml,{tag=>$tag,chars=>0};
  if($tag eq 'binary'){
    print " ",$params if length $params;
    print "\n";
  }
}


sub CloseTag($){ my $tag=shift;
  my $opened=$xml[$#xml]{'tag'};
  unless($opened eq $tag){
    OutWarn "opened <$opened> != closed <$tag>";
    return;
  }
  --$skipcounter if $tag_style{$tag}{'skip'};
  if(defined $tag_style{$tag}){
    print $tag_style{$tag}{'end'};
  }elsif( $xml[$#xml] {'chars'} ){
    print "\n";
  }
  if($tag eq 'section'){
    pop @level;
  }elsif($tag eq 'body'){
    pop @level;
  }
  pop @xml;
  if($structures{$tag}){
    pop @structure;
  }
}


sub OutText($){ my $txt=shift;
  return if $skipcounter;
  return unless length $txt;
  my $x=$xml[$#xml];
  my $tag=$x->{'tag'};
  unless($x->{'chars'} or defined $tag_style{$tag}){
    print ucfirst($tag),": ";
  }
  $txt = UtfChars($txt) if $source_cp eq 'utf-8';
  Encode::from_to($txt,$source_cp,$target_cp) if $encode_cp;
  print GoodChars($txt);
  $x->{'chars'}+=length $txt;
}


sub Convert{
  $skipcounter=0;
  while(<>){
    tr/\r\n//d;
#    chomp;
    s/^\s+//;
    while($_){
      if(/^(.*?)\<(.)(.*?)\>(.*)$/){
        $_=$4;
        OutText($1) if length $1;
        if($2 eq '/'){
          CloseTag(lc $3);
        }else{
          OpenTag(lc $2.$3);
        }
      }else{
        OutText($_."\n");
        last;
      }
    }
  }
}



############################### Main ##########################

my @params=@ARGV;
my $done=0;
for(@params){
  if(/^-cp\=(.*)$/){
    $target_cp=$1;
    $encode_cp=$target_cp?1:0;
  }else{
    @ARGV=($_);
    die "Cant redirect out.\n" unless open STDOUT,'>',$_.".txt";
    Convert();
    ++$done;
  }
}

unless(@ARGV){
  die "No arguments found. Example: fb2text -cp cp1251 book.fb2"
}
Convert() unless $done;

# if(@ARGV){
#   my @files=@ARGV;
#   @ARGV=();
#   for(@files){
#     push @ARGV,$_;
#     die "Cant redirect out.\n" unless open STDOUT,'>',$_.".txt";
#     Convert();
#   }
# }else{
#   Convert();
# }
