package Vmsgs::Msg;

# An object for manipulating msgs

use Symbol;
use strict;

# The order headers should be in
our @HEADER_ORDER = ('From','From:','Subject:','Date:','Followup-to:','X-msgs-client:',
                     'X-posting-host:','Content-length:');  

our $VERSION = "1.0";
our $DEBUG = 0;

# Create a new instance of a msg.  All arguments are optional.
# $header and $body are references to items.
sub new {
my($class,$id,$header,$body) = @_;
  my($self);
  
  $self->{'id'} = $id;

  $self->header($header) if ($header);
  $self->body($body) if ($body);

  print "Creating new Msg object $self\n" if ($DEBUG);
  bless $self,$class;
}


# Get or set the id
sub id {
my($self,$id) = @_;

  if (defined($id)) {
    $self->{'id'} = $id;
  } else {
    $self->{'id'};
  }
} # end id


# Get or set the message body.  Pass in a ref to either a ref to a
# scalar (the whole text of the msg), or a ref to an array (one line 
# per element).  It can return either a scalar or an array.
sub body {
my($self,$ref) = @_;
  my($len);

  print "In Msg::body\n" if ($DEBUG);

  if (defined($ref)) {  # To set the body
    if (!ref($ref)) {  # If it was a scalar
      print "setting body as a scalar >>$ref<<\n" if ($DEBUG);
      $self->{'body'} = $ref;
    } elsif (ref($ref) eq 'SCALAR') {  # It was a ref to a scalar
      print "setting body as a scalar ref >>$$ref<<\n" if ($DEBUG);
      $self->{'body'} = $$ref;
    } elsif (ref($ref) eq 'ARRAY') {  # It was a ref to an array
      print "Setting body as an array ref >>" if ($DEBUG);
      $self->{'body'} = "";  # Clear it out first
      foreach ( @$ref) {
        $self->{'body'} .= $_;
        if (! m/\n$/) {
          $self->{'body'} .= "\n";  # Tack on newlines if the element dosen't have them already
        }
      }
      print $self->{'body'},"<<\n" if ($DEBUG);
    } else {
      warn "Assigning unknown reference type ",ref($ref)," to body of msg";
      return undef;
    }
  } else {  # $ref is undef, get the body
    print "Getting body\n" if ($DEBUG);
    if (wantarray()) {
      return split(/^/,$self->{'body'});
    } else {
      return $self->{'body'};
    }
  }
} # end body



# Get or set all the headers at once, or just get or set a single header
sub header {
my($self,$arg1,$arg2) = @_;
  my($headers,@list);

  print "In Msg::header arg1 $arg1 arg2 $arg2\n" if ($DEBUG);

  if (defined($arg1) && defined($arg2)) { # 2 args, must be setting a single header
    if ($arg1 eq "From") {  # The from header is a phantom header, it's not actually stored in that form
      print "setting From header\n" if ($DEBUG);
      my($from,$email,$date) = ($arg2 =~ m/(\S+)\s+\((\S+)\)\s+(.*)/);
      print "matched From: $from Email $email Date: $date\n" if ($DEBUG);
      $self->header("From:",$from);
      $self->header("Email",$email);
      $self->header("Date:",$date);
    } elsif ($arg1 eq "From:") {
      print "setting From: header\n" if ($DEBUG);
      my($author,$email);
      ($author) = ($arg2 =~ m/^(\w+)/);
      $self->header("Author", $author) if ($author);
      ($email) = ($arg2 =~ m/\<(.*)\>/);
      $self->header("Email", $email) if ($email);
      $self->{'headers'}->{'From:'} = $arg2;
    } elsif ($arg1 =~ m/Reply-To:/i) {
      $self->header("Followup-to:", $arg2);
    } else {
      print "setting $arg1 header to $arg2\n" if ($DEBUG);
      $self->{'headers'}->{$arg1} = $arg2;
    }

  } elsif (defined($arg1) && ref($arg1)) {  # arg1 is a reference to something, must be setting all headers
    print "setting all headers\n" if ($DEBUG);
    $headers = &_parse_headers($arg1);
    $self->{'headers'} = $headers;

  } elsif (defined($arg1) && !ref($arg1)) { # arg1 is a plain ol' string, must be getting a single header
    # If we're looking for 'Content-length:' and it's not set, and the body has been loaded...
    if (($arg1 eq "Content-length:") &&
        ! $self->{'headers'}->{'Content-length:'} &&
        length($self->{'body'})) {
      print "calculating content-length\n" if ($DEBUG);
print "body is >>",$self->{'body'},"<<\n" if ($DEBUG);
      $self->{'headers'}->{'Content-length:'} = &_count_lines($self->{'body'});
      $self->{'headers'}->{$arg1};
    } elsif ($arg1 eq "From") {
      print "getting From header\n" if ($DEBUG);
      $self->{'headers'}->{'From'} ||
        $self->header('Author') . " (" . $self->{'headers'}->{'Email'} . ") ". $self->{'headers'}->{'Date:'};
    } elsif ($arg1 eq "From:") {
      print "getting From: header\n" if ($DEBUG);
      $self->{'headers'}->{'From:'} ||
        $self->{'headers'}->{'Author'} . " <" . $self->{'headers'}->{'Email'} . ">";
    } else {
      print "getting $arg1 header\n" if ($DEBUG);
      $self->{'headers'}->{$arg1};
    }

  } else {   # No args supplied, must be getting all headers
    print "getting all headers\n" if ($DEBUG);
    my($string,%all_headers);

    %all_headers = %{$self->{'headers'}};
    foreach (@HEADER_ORDER) {
      
      next unless($string = $self->header($_));
      # next unless($string = $all_headers{$_});
      delete($all_headers{$_});
      push(@list,"$_ $string");
    }
    
    # Now, tack on all the extra headers on the end
    foreach ( keys(%all_headers) ) {
      next unless ($string = $all_headers{$_} && $string =~ m/:$/);
      push(@list, "$_ $string");
    }
    if (wantarray()) {
      @list;
    } else {
      join("",@list);
    }
  }
} # end header


# Load in everything for a msg at once.  
sub load {
my($self,$string) = @_;
  my($fh,$headers,$body);

  print "In Msg::load()\n" if ($DEBUG);

  ($headers) = ($string =~ m/(.*?\n)\n/s);
  $string =~ s/.*?\n\n//s;

  print "Split out headers >>$headers<<\nsplit out body >>$string<<\n" if ($DEBUG);

  $self->header(\$headers);
  $self->body($string);

  $self->header("Content-length:",0); # Force it to count the lines in the body
  $self->header("Content-length:", $self->header("Content-length:")); 
}



sub SaveToFile {
my($self,$file) = @_;
  my($fh);

  $fh = gensym();
  if(!open($fh,">$file")) {
    warn "Can't open file $file for writing: $!";
    return undef;
  }

  print $fh $self->Textify();
 
  close($fh);

  return 1;
} # end save_to_file


sub LoadFromFile {
my($self,$file) = @_;
  my($fh,$string);

  $fh = gensym();
  if(!open($fh,"$file")) {
    warn "Can't open file $file for reading: $!";
    return undef;
  }

  local $/;  # Read in the whole file as a scalar
  $string = <$fh>;
  close($fh);

  $self->load($string);
} # end LoadFromFile

# Convert a msg structure to a flat text representation
sub Textify {
my($self) = @_;
  my($string,@list,$body);

  @list = $self->header();

  print "msg has ",scalar(@list)," headers\n" if ($DEBUG);
  foreach ( @list ) {
    $string .= "$_";
    $string .= "\n" unless ($string =~ m/\n$/);
  }
  $string .= "\n";

  $body = $self->body();
  if (length($body)) {
    $string .= $body;
  } else {
    $string .= "\n";
  }

  $string;
} # end Textify


# Rearranges the body of a msg to fit within a certain sized window
sub Justify {
my($self,$columns) = @_;
  my($string,$word,@words,$col);

  print "Justifying msg ",$self->{'id'}," to $columns columns\n" if ($DEBUG);

  $self->{'body'} =~ s/\n/ /g;  # Convert newlines to spaces
  @words = split(/\s/,$self->{'body'});

  while($word = shift(@words)) {
    if (length($word) + $col > $columns) {
      print "next word $word is too big\n" if ($DEBUG);
      if (length($word) > $columns) {
        print "word $word is bigger than the column size\n" if ($DEBUG);
        $string .= "\n$word\n";
        $col = 0;
      } else {
        print "starting new line at $word\n" if ($DEBUG);
        $string .= "\n$word ";
        $col = length($word) + 1;
      }
    } else {
      print "taking on word $word\n" if ($DEBUG);
      $string .= "$word ";
      $col += length($word) + 1;
    }
  }

  $string;
} # end Justify


sub AppendSig {
my($self) = @_;
  my($file,$fh);

  print "In Msg::AppendSig\n" if ($DEBUG);
  $file = $ENV{'HOME'} . "/.msgssig";
  $fh = gensym();
  return unless (open($fh,$file));

  print "Reading in the /msgssig file\n" if ($DEBUG);
  $file = join("",<$fh>);
#  $self->{'body'} .= "\n--\n$file";
  $self->{'body'} .= "\n$file";
  close($fh);
}


# Pass in a ref to a scalar or a ref to a list
sub _parse_headers {
my($ref) = @_;
  my(@list,%head);

  print "in Msg::_parse_headers\n" if ($DEBUG);

  if (!ref($ref)) {
    print "splitting scalar headers into list >>$ref<<\n" if ($DEBUG);
    @list = split(/^/,$ref);
  } elsif (ref($ref) eq 'SCALAR') {
    print "splitting scalar ref into list >>$$ref<<\n" if ($DEBUG);
    @list = split(/^/,$$ref);
  } elsif (ref($ref) eq 'ARRAY') {
    my($item);
    print "copying list ref into list\n" if ($DEBUG);
    while($item = shift(@$ref)) {
      push(@list,$item);
    }
  } else {
    warn "Unknown reference type ",ref($ref)," passed into _parse_headers";
    return undef;
  }

  print "list has ",scalar(@list)," items\n" if ($DEBUG);
  foreach ( @list ) {
    chomp;
    last unless ($_);
    my($header,$value);
    print "read line >>$_<<\n" if ($DEBUG);
    ($header,$value) = (m/^([-\w]+:?) (.*)/);
    $head{$header} = $value;
    print "header >>$header<< value >>",$head{$header},"<<\n" if ($DEBUG);
  }

  if ($head{'From'} =~ m/(\w+)\s+\((\S+)\)\s+(.*)$/ ) {
    print "From matched\n" if ($DEBUG);
    $head{'Author'} = $1;
    $head{'Email'} = $2;
    $head{'Date:'} = $head{'Date:'} || $3;
  } elsif ($head{'From'} =~ m/(\w+)\s+(.*)$/ ) {
    print "shorter From matched\n" if ($DEBUG);
    $head{'Author'} = $1;
    $head{'Date:'} = $2;
    $head{'Email'} = $1;
  }


  \%head;
}


# Returns the number of lines in the argument
sub _count_lines {
my($string) = @_;
  my($lines);

  while($string =~ s/^[^\n]*\n//m) {
    $lines++;
  }

  $lines++ if ($string);

  $lines;
}

1;
