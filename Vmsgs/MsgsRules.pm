package Vmsgs::MsgsRules;

use IO::File;

# Implements the interaction between Msg objects and the .msgsrules file

use Symbol;

$VERSION = "1.0";
$DEBUG = 0;

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
    $fh = IO::File->new($filename);

    if ($fh) {
      print STDERR "Processing msgs rule file\n" if ($DEBUG);
      while(<$fh>) {
        chomp;
        print STDERR "got a line: >>$_<<\n" if ($DEBUG);
        my($node);

#        if (m/(\w+)\s+(\w+)\s+(\w+)/) {
        if (m/(\w+)\s+(\w+)\s+(\S+)/) {
          print STDERR "Matched! action $1 area $2 pattern $3\n" if ($DEBUG);

          $node->{'action'} = $1;
          $node->{'area'} = $2;
          $node->{'pattern'} = $3;

          push(@{$self->{'list'}},$node);
        } else {
          print STDERR "Line didn't match :(\n" if ($DEBUG);
        }
      } # end while $fh
      print STDERR "Done reading file\n" if ($DEBUG);
      $fh->close();
    } else {
      print STDERR "Didn't open $filename: $!\n" if ($DEBUG);
    }
  }

  $self;
} # end new


# Create a new object with all the same rules as the original
sub clone {
my($self) = @_;
  my $class = ref($self) || $self;
  my $newobj = $class->new(skip => 1);

  foreach (@{$self->{'list'}}) { 
    push(@{$newobj->{'list'}},$_);
  }
  $newobj->{'is_search'} = $self->{'is_search'};
print STDERR "Cloning a new rules object $self with ",scalar(@{$newobj->{'list'}})," rules\n" if ($DEBUG);

  $newobj;
} # end clone
    

# These add new rules at runtime but don't affect the killfile on disk
sub push {
my($self,$action,$area,$pattern) = @_;
  my $node;
  $node->{'action'} = $action;
  $node->{'area'} = $area;
  $node->{'pattern'} = $pattern;

print STDERR "pushing new rule onto $self action $action area $area pattern $pattern\n" if ($DEBUG);
  push @{$self->{'list'}}, $node;
}

sub unshift {
my($self,$action,$area,$pattern) = @_;
  my $node;
  $node->{'action'} = $action;
  $node->{'area'} = $area;
  $node->{'pattern'} = $pattern;

  unshift @{$self->{'list'}}, $node;
}

  
# used by the search functionality to eliminate all the
# rules to force a msg to pass, and 
sub prepare_search {
my($self) = @_;

  if ($self->{'is_search'}) {
    print STDERR "$self is already a search-type rule\n";
    return 1;
  }

  my @newlist;
  # copy all the 'skip'-type rules so they won't see things they
  # explicitly didn't want to see form the .msgsrules file
  foreach ( @{$self->{'list'}} ) {
    push @newlist,$_ if ($_->{'action'} ne 'read');
  }
  $self->{'list'} = \@newlist;

  $self->{'is_search'} = 1;  # makes pass() behave differently
}


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
    print STDERR "renaming $file to $file.old\n" if ($DEBUG);
    rename($file,"$file.old") || warn "can't rename $file to $file.old: $!\n";
  } else {
    unlink("$file.old");
  }
 
  $newfh = IO::File->new(">$file");
  if (!$newfh) {
    print STDERR "Can't open killfile $file for writing: $!\n";
    return;
  }
  $oldfh = IO::File->new("$file.old");
  
  $newfh->print("$action $area $pattern\n");
  $newfh->print foreach ($oldfh->getlines());  # This reads in the old file and writes it to the new one
  $newfh->close();
  $oldfh->close();
} # end add

# Returns true if this msg passes the rules tests, false otherwise
sub pass {
my($self,$msg) = @_;

print STDERR "seeing if msg $msg ",$msg->id," passes the rules tests for $self\n" if ($DEBUG);
print STDERR scalar(@{$self->{'list'}})," rules\n" if ($DEBUG);

  foreach my $node ( @{$self->{'list'}} ) {
    next unless $node;
    my $flag = 0;
    printf(STDERR "node action %s area %s pattern %s\n",
           $node->{'action'}, $node->{'area'},$node->{'pattern'}) if ($DEBUG);
    my $pattern = $node->{'pattern'};

    my $regex;
    if ($pattern && !$node->{'regex'}) {
      $node->{'regex'} = eval { qr/$pattern/};
      if (!$node->{'regex'}) {
        printf STDERR "Can't compile rule into pattern, action %s area %s pattern %s\n",$node->{'action'},$node->{'area'},$node->{'pattern'};
        $node = undef;
        next;
      }
    }
    $regex = $node->{'regex'};
  
    if ($node->{'area'} eq "from") {
      print STDERR "looking for Author match $regex\n" if ($DEBUG);
      $flag = ($msg->header("Author") =~ m/$regex/);
    } elsif ($node->{'area'} eq "subject") {
      print STDERR "looking for subject match $regex\n" if ($DEBUG);
      print STDERR "against subject >>",$msg->header("Subject:"),"<<\n" if ($DEBUG);
      $flag = ($msg->header("Subject:") =~ m/$regex/);
    } elsif ($node->{'area'} eq "body") {
      print STDERR "looking for body match pattern $regex\n" if ($DEBUG);
      $flag = ($msg->body() =~ m/$regex/);
    } elsif ($node->{'area'} eq "remaining") {
      print STDERR "area was remaining, matching\n" if ($DEBUG);
      $flag = 1;
    }

    # If this is a search-type rule, then a msg must pass _all_
    # the tests to pass.  For a normal-type rule, then it just has to
    # pass any one of the rules
    if ($self->{'is_search'} && ! $flag) {
      print STDERR "flag was false and we're a search-type rule, fail!\n" if ($DEBUG);
      return 0;
    }

    print STDERR "flag was 1\n" if ($DEBUG);

    if ($node->{'action'} =~ m/read/i) {
      print STDERR "Pass!\n" if ($DEBUG);
      return 1 unless ($self->{'is_search'});
    } elsif ($node->{'action'} =~ m/skip/i) {
      print STDERR "Fail!\n" if ($DEBUG);
      return 0;
    } else {
      warn "unknown msgsrules action: $action\n";
      return 1;
    }
  } # end while

  print STDERR "done checking rules, default is pass\n" if ($DEBUG);

  1;
} # end pass


sub filename {
my($self) = @_;

  $self->{'filename'};
}

package Vmsgs::MsgsRules::Searcher;
use base qw ( Vmsgs::MsgsRules );

sub pass {
my($class,%args) = @_;
  if (! $RULE_OBJ) {
    $RULE_OBJ = $class->SUPER::new(%args);
  }
  $RULE_OBJ;
}
  


1;
