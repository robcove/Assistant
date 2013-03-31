#!/usr/bin/perl -w

use Net::OSCAR qw(:standard);
use Date::Manip;
 
my $screenname = "SCREENNAME";
my $password = "PASSWORD";
my $master = "MASTERSCREENNAME"

my $oscar = Net::OSCAR->new();

my @reminders; # array of hashes { whoToRemind, whatToRemind, whenToRemind }
my $time;
my $reminder;
 
sub im_in {
  my($oscar, $sender, $message, $is_away) = @_;
  $message =~ s/<[^<]+>//g; # really dirty
  $message =~ s/<font[^<]+>//ig; # remove font tags
  $message =~ s/<\/font>//ig;    # 
  print "[AWAY] " if $is_away;
  print "$sender: $message\n"; 
  if ($message =~ m/^\s*remind\s+me\s+(to\s+.+|that\s+.+|\"[^\"]+\"\"s+)(in|at|on|\@)\s+.+/i) { 
  # check if it's valid (dirty)
  # don't need the (to|that|"") stuff really
  # split the message into whatToRemind, whenToRemind... check if whenToRemind is valid 
    $message =~ s/\s+/ /g;           # remove superfluous whitespace
    $message =~ s/^\s*remind me //;  # remove everything before what we want to remind 
    $message =~ s/\s+$//;            # remove trailing whitespace
    if ($message =~ m/.+ (in|at|on|\@) /) {
      $time = $';
      if ($time =~ m/[0-9]+/g) {
        if ($& > 9999) {
          $oscar->send_im($sender, "The interval you requested is too large, jerk.");
        }
        else {
          $time = ParseDate($time);
        }
      }  
      #print "is $time valid?\n";
      if (!$time) {
        $oscar->send_im($sender, "I don't understand when you want me to remind you.");
        print "$sender gave me a bad time\n";
      }
      if ($time) {
        if (Date_Cmp($time, "now") <= 0) { # if requested time is now or in the past...
          $oscar->send_im($sender, 'The time you requested has already passed.
            I can only remind you to do things in the future!');
        } 
        else { # all good?
          $message =~ s/ (in|at|on|\@).*//; # remove the trailing in/at/on/@ to get just the reminder
          push(@reminders, { whoToRemind => "$sender", 
                            whatToRemind => "$message", 
                            whenToRemind => "$time" });
          print "$sender wants me to remind him $message at $time\n";
        } 
      }
    } 
#    $oscar->send_im($sender, 'Will do');
  } 
}

sub signon_done {
  print "Signon successful!\n";
#  $oscar->send_im($master', 'Hello');
}

$oscar->set_callback_signon_done(\&signon_done); 
$oscar->set_callback_im_in(\&im_in);

$oscar->signon($screenname, $password);

while(1) {
  $oscar->do_one_loop();
  for $i (0 .. $#reminders) {
    if (Date_Cmp($reminders[$i]{whenToRemind}, "now") == 0) {
      $reminder = $reminders[$i]{whatToRemind};
      $reminder =~ s/\bI\b/ you /gi;
      $reminder =~ s/\bmy\b/ your /gi;
      $oscar->send_im($reminders[$i]{whoToRemind}, 
        "You asked me to remind you $reminders[$i]{whatToRemind}");
      print "I reminded $reminders[$i]{whoToRemind} \"$reminder\" \@ $reminders[$i]{whenToRemind}\n";
      splice(@reminders, $i, 1);
      $i--;
    }
  }
}
