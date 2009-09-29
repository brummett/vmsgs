package Vmsgs::Debug;

use IO::File;
use strict;

# inheritable package to let modules write debugging info to a file

our %FILE_NAMES;

sub start_debug {
my($self,$file) = @_;
  my($fh);

  if ($fh = $FILE_NAMES{$file}) {
    $self->{'_debug'}->{'fh'} = $fh;
    print $fh "Attaching new object to existing FH\n";
  } else {
    $fh = new IO::File("> $file");
    if (!$fh) {
      print STDERR "Can't open debug file $file: $!";
      return undef;
    }
    $fh->autoflush(1);
 
    $self->{'_debug'}->{'filename'} = $file;
    $self->{'_debug'}->{'fh'} = $fh;
    $FILE_NAMES{$file} = $fh;
 
    print $fh "Debug started ",scalar(localtime()),"\n\n";
  }
} # end start_debug


sub Debug {
return;
my($self,$msg) = @_;
  my($time,$fh,@caller);
  
  if (defined($self->{'_debug'}->{'fh'})) {
    ($time) = (scalar(localtime()) =~ m/(\d+\:\d+\:\d+)/);
 
    @caller = caller(1);
    $fh = $self->{'_debug'}->{'fh'};
 
    print $fh "$time [$$] ",$caller[3],": $msg\n";
  }
} # end Debug


1;

  


