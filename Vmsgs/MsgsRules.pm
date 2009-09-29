package Vmsgs::MsgsRules;

# Implements the interaction between Msg objects and the .msgsrules file

use Symbol;

$VERSION = "1.0";
$DEBUG = $main::DEBUG;

# Loads the .msgsrules file and creates the data structure for it
sub new {
my($class,%args) = @_;
  my($self,$fh,$filename);

  $self->{'list'} = [];

  bless $self,$class;
  if ($args{'skip'}) {
    return $self;
  }

  $filename = $args{'filename'} || $ENV{'HOME'} . "/.msgsrules";
  $self->{'filename'} = $filename;

  if (-f $filename) {
    $fh = gensym();

    if (open($fh,$filename)) {
      print "Processing msgs rule file\n" if ($DEBUG);
      while(<$fh>) {
        chomp;
        print "got a line: >>$_<<\n" if ($DEBUG);
        my($node);

#        if (m/(\w+)\s+(\w+)\s+(\w+)/) {
        if (m/(\w+)\s+(\w+)\s+(\S+)/) {
          print "Matched! action $1 area $2 pattern $3\n" if ($DEBUG);

          $node->{'action'} = $1;
          $node->{'area'} = $2;
          $node->{'pattern'} = $3;

          push(@{$self->{'list'}},$node);
        } else {
          print "Line didn't match :(\n" if ($DEBUG);
        }
      } # end while $fh
      print "Done reading file\n" if ($DEBUG);
      close($fh);
    } else {
      print "Didn't open $filename: $!\n" if ($DEBUG);
    }
  }

  $self;
} # end new


# Add a new rule at runtime, and add it to the start of the file
sub add {
my($self,$action,$area,$pattern) = @_;
  my($node,$file,$newfh,$oldfh);

  $node->{'action'} = $action;
  $node->{'area'} = $area;
  $node->{'pattern'} = $pattern;

  $file = $self->{'filename'};

  unshift(@{$self->{'list'}},$node); # Add the new rule to the start of the list

  # Now, save the new rule to the top of the file
  if (-f $file) {
    print "renaming $file to $file.old\n" if ($DEBUG);
    rename($file,"$file.old") || warn "can't rename $file to $file.old: $!\n";
  } else {
    unlink("$file.old");
  }
 
  $newfh = gensym();
  $oldfh = gensym();
  open($newfh,">$file") || warn "can't open $file for writing: $!\n";
  open($oldfh,"$file.old");
  
  print $newfh "$action $area $pattern\n";
  grep(print($newfh $_),<$oldfh>);  # This reads in the old file and writes it to the new one
  close($newfh);
  close($oldfh);
} # end add

# Returns true if this msg passes the rules tests, false otherwise
sub pass {
my($self,$msg) = @_;
  my($node,$flag,$pattern);

  print "seeing if msg $msg passes the rules tests\n" if ($DEBUG);

  foreach $node ( @{$self->{'list'}} ) {
    $flag = 0;
    printf("node action %s area %s pattern %s\n",
           $node->{'action'}, $node->{'area'},$node->{'pattern'}) if ($DEBUG);
    $pattern = $node->{'pattern'};
  
    if ($node->{'area'} eq "from") {
      print "looking for Author match $pattern\n" if ($DEBUG);
      $flag = ($msg->header("Author") =~ m/$pattern/);
    } elsif ($node->{'area'} eq "subject") {
      print "looking for subject match $pattern\n" if ($DEBUG);
      $flag = ($msg->header("Subject:") =~ m/$pattern/);
    } elsif ($node->{'area'} eq "body") {
      print "looking for body match pattern $body\n" if ($DEBUG);
      $flag = ($msg->body() =~ m/$pattern/);
    } elsif ($node->{'area'} eq "remaining") {
      print "area was remaining, matching\n" if ($DEBUG);
      $flag = 1;
    }

    next unless $flag;

    print "flag was 1\n" if ($DEBUG);

    if ($node->{'action'} =~ m/read/i) {
      print "Pass!\n" if ($DEBUG);
      return 1;
    } elsif ($node->{'action'} =~ m/skip/i) {
      print "Fail!\n" if ($DEBUG);
      return undef;
    } else {
      warn "unknown msgsrules action: $action\n";
      return 1;
    }
  } # end while

  print "done checking rules, default is pass\n" if ($DEBUG);

  1;
} # end pass


sub filename {
my($self) = @_;

  $self->{'filename'};
}

1;
