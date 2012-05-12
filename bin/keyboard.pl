#!/usr/bin/perl -w

BEGIN {
    eval("use Wx 0.93;");
    if($@) {
	die("Requires Wx perl module (latest from CPAN or Debian Sid)");
    }
    eval("require XML::Quote;");
    if($@) {
	die("Requires XML::Quote perl module (from CPAN or libxml-quote-perl package)");
    }
    eval("require XML::Mini::Document;");
    if($@) {
	die("Requires XML::Mini::Document perl module (from CPAN or libxml-mini-perl package)");
    }
    eval("require File::Find::Rule;");
    if($@) {
	die("Requires File::Find::Rule perl module (from CPAN or libfile-find-rule-perl package)");
    }
}

use XML::Quote qw(xml_dequote);

system(qw(xmodmap -e), "keycode 157 = 65469");
=begin
system(qw(xmodmap -e), "keycode 182 = 65441");
system(qw(xmodmap -e), "keycode 183 = 65442");
system(qw(xmodmap -e), "keycode 184 = 65443");
=cut

my $escape = sub {
    my $class = shift;
    my $toencode = shift;

    return undef unless (defined $toencode);

    $toencode = xml_dequote($toencode);
    $toencode =~ s/&#(\d+);/chr($1)/ge;
    $toencode =~ s/\\\\/\\/g;

    return $toencode;
};

use Sub::Override;
my $override = Sub::Override->new("XML::Mini::escapeEntities", $escape);

package MyDialog;

use Wx qw(wxDefaultSize wxDefaultValidator wxID_ANY wxDefaultPosition wxICON_ERROR wxFONTFAMILY_DEFAULT wxFONTSTYLE_NORMAL wxFONTWEIGHT_BOLD);
use Wx::Event qw(EVT_KEY_DOWN EVT_CLOSE EVT_LEFT_DOWN EVT_BUTTON);

use base 'Wx::Frame';
sub new {
    my( $class, $next ) = @_;
    my $this = $class->SUPER::new( undef, -1, "", [-1, -1], [250, 110] );
    $this->{'last'} = $next;
    $this->{'myjunk'} = {};
    my @modes = qw(advanced basic);
    my $i_mode = $main::default_mode eq 'advanced' ? 0 : 1;
    my @profiles = ();
    my @keyboards = ();
    my $i;
    my $i_keyboards;
    my $i_profiles;
    $i = 0;
    foreach(@{[keys(%{$main::keyboards})]}){
	push @keyboards, $_;
	$i_keyboards = $i if($main::keyboards->{$_} eq $main::default_keyboard);
	$i += 1;
    }
    $i = 0;
    foreach(@{[keys(%{$main::profiles})]}){
	push @profiles, $_;
	$i_profiles = $i if($main::profiles->{$_} eq $main::default_profile);
	$i += 1;
    }
    Wx::StaticText->new($this, wxID_ANY, "Display Profiles:", wxDefaultPosition, wxDefaultSize, 0, "");
    $this->{'myjunk'}->{'profiles'} = Wx::ListBox->new($this, wxID_ANY, [0, 20], [300, 200], \@profiles, 0, wxDefaultValidator, "");
    Wx::StaticText->new($this, wxID_ANY, "Keyboard Layouts:", [0, 220], wxDefaultSize, 0, "");
    $this->{'myjunk'}->{'keyboards'} = Wx::ListBox->new($this, wxID_ANY, [0, 240], [300, 200], \@keyboards, 0, wxDefaultValidator, "");
    Wx::StaticText->new($this, wxID_ANY, "Mouse Testing Display Modes:", [0, 440], wxDefaultSize, 0, "");
    $this->{'myjunk'}->{'modes'} = Wx::ListBox->new($this, wxID_ANY, [0, 460], [300, 200], \@modes, 0, wxDefaultValidator, "");
    $this->{'myjunk'}->{'profiles'}->SetSelection($i_profiles);
    $this->{'myjunk'}->{'keyboards'}->SetSelection($i_keyboards);
    $this->{'myjunk'}->{'modes'}->SetSelection($i_mode);
    my $button = Wx::Button->new($this, wxID_ANY, "OK", [0, 660]);
    EVT_BUTTON($button, wxID_ANY, sub { OnButton($this); });
#    if(`bash -c '. /etc/default/wx-keyboard-tester; echo -n \$DISABLED'` ne "1") {
#	my $a_button = Wx::Button->new($this, wxID_ANY, "Admin", [0, 480]);
#	EVT_BUTTON($a_button, wxID_ANY, sub { OnAdmin($this); });
#    }
    EVT_CLOSE( $this, \&OnClose );
    $this->Show;
    $this->ShowFullScreen(1);
    return $this;
}

sub start {
    my $class = shift;
    my $next = shift;
    if($main::mainwindow) {
	$main::mainwindow->Destroy();
    }
    $main::mainwindow = $class->new($next);
    $main::windowtype = "settings";
}

sub save_settings {
    open my $F, ">", $main::user_settings_file;
    print $F "<profile>" . $main::default_profile . "</profile>\n";
    print $F "<keyboard>" . $main::default_keyboard . "</keyboard>\n";
    print $F "<mode>" . $main::default_mode . "</mode>\n";
    close $F;
}

#sub OnAdmin {
#    my $this = shift;
#    my $res = Wx::GetPasswordFromUser("What's the admin password?", "Enter password", "", $this);
#    if($res eq "4321") {
#	system("touch /tmp/wx-keyboard-tester.disabled");
#	system("reboot");
#	$this->Destroy;
#    } else {
#	Wx::MessageBox("Incorrect password", "", wxICON_ERROR, $this);
#    }
#}

sub OnButton {
    my $this = shift;
    $main::default_profile = $main::profiles->{$this->{'myjunk'}->{'profiles'}->GetStringSelection()};
    $main::default_keyboard = $main::keyboards->{$this->{'myjunk'}->{'keyboards'}->GetStringSelection()};
    $main::default_mode = $this->{'myjunk'}->{'modes'}->GetStringSelection();
    save_settings();
    $this->{'last'}->start();
    $this->Destroy;
}

sub OnClose {
    my( $this, $event ) = @_;
    $this->Destroy;
}

package MyMouseWindow;

use Wx qw(wxDefaultSize wxDefaultValidator wxID_ANY  wxFONTFAMILY_DEFAULT wxFONTSTYLE_NORMAL wxFONTWEIGHT_BOLD wxFONTWEIGHT_MAX);
use Wx::Event qw(EVT_KEY_DOWN EVT_PAINT EVT_CLOSE EVT_LEFT_DOWN EVT_BUTTON EVT_LEFT_UP EVT_MIDDLE_UP EVT_RIGHT_UP EVT_MOUSEWHEEL);

use base 'Wx::Frame';

sub start {
    my $class = shift;
    if($main::mainwindow) {
	$main::mainwindow->Destroy();
    }
    $main::mainwindow = $class->new();
    $main::windowtype = "mtester";
}

sub Restart {
    MyMouseWindow->start();
}

sub Settings {
    MyDialog->start(MyMouseWindow);
}

sub Keyboard {
    MyKeyboardWindow->start();
}

sub colour_from_setting {
    my $name = shift;
    return Wx::Colour->new($main::settings{$name}->{'r'}, $main::settings{$name}->{'g'}, $main::settings{$name}->{'b'});
}
sub new {
    my( $class, $label ) = @_;
    my $xmlHash = main::load_xml("profiles", $main::default_profile);
    foreach(@{$xmlHash->{settings}->{setting}}) {
	$main::settings{$_->{'name'}} = $_;
    };
    my $this = $class->SUPER::new( undef, -1, "", [-1, -1], [250, 110] );
    my $restart_button = Wx::Button->new($this, wxID_ANY, "Restart", [300, 0]);
    EVT_BUTTON($restart_button, wxID_ANY, \&Restart);
    my $keyboard_button = Wx::Button->new($this, wxID_ANY, "Keyboard", [0, 0]);
    EVT_BUTTON($keyboard_button, wxID_ANY, \&Keyboard);
    my $settings_button = Wx::Button->new($this, wxID_ANY, "Settings", [200, 0]);
    EVT_BUTTON($settings_button, wxID_ANY, \&Settings);
    my $quit_button = Wx::Button->new($this, wxID_ANY, "Shut Down", [100, 0]);
    EVT_BUTTON($quit_button, wxID_ANY, sub {$this->OnClose;});

    my $start_background = colour_from_setting('unpressed_color');
    my $start_foreground = colour_from_setting('unpressed_text');

    my $end_background = colour_from_setting('pressed_color');
    my $end_foreground = colour_from_setting('pressed_text');

    my $text = Wx::StaticText->new($this, wxID_ANY, "Click each box using the mouse button it is labelled with if there is one:", [0, 30], wxDefaultSize, 0, "");
    $text->SetFont(Wx::Font->newLong(16, wxFONTFAMILY_DEFAULT, wxFONTSTYLE_NORMAL, wxFONTWEIGHT_MAX, 0));

    my $button = Wx::Button->new($this, wxID_ANY, "Left Click", [80, 60]);
    $button->SetFont(Wx::Font->newLong(14, wxFONTFAMILY_DEFAULT, wxFONTSTYLE_NORMAL, wxFONTWEIGHT_MAX, 0));
    $button->SetFocus();
    $button->SetBackgroundColour($start_background);
    $button->SetForegroundColour($start_foreground);
    $button->SetSize(Wx::Size->new(120, 30));
    EVT_LEFT_UP($button, sub {my ($this, $event) = @_; $button->SetBackgroundColour($end_background); $button->SetForegroundColour($end_foreground); $event->Skip();});

    my $button2 = Wx::Button->new($this, wxID_ANY, "Middle Click", [290, 60]);
    $button2->SetFont(Wx::Font->newLong(14, wxFONTFAMILY_DEFAULT, wxFONTSTYLE_NORMAL, wxFONTWEIGHT_MAX, 0));
    $button2->SetFocus();
    $button2->SetBackgroundColour($start_background);
    $button2->SetForegroundColour($start_foreground);
    $button2->SetSize(Wx::Size->new(120, 30));
    EVT_MIDDLE_UP($button2, sub {my ($this, $event) = @_; $button2->SetBackgroundColour($end_background); $button2->SetForegroundColour($end_foreground); $event->Skip();});

    my $button3 = Wx::Button->new($this, wxID_ANY, "Right Click", [500, 60]);
    $button3->SetFont(Wx::Font->newLong(14, wxFONTFAMILY_DEFAULT, wxFONTSTYLE_NORMAL, wxFONTWEIGHT_MAX, 0));
    $button3->SetFocus();
    $button3->SetBackgroundColour($start_background);
    $button3->SetForegroundColour($start_foreground);
    $button3->SetSize(Wx::Size->new(120, 30));
    EVT_RIGHT_UP($button3, sub {my ($this, $event) = @_; $button3->SetBackgroundColour($end_background); $button3->SetForegroundColour($end_foreground); $event->Skip();});

    my $text2 = Wx::StaticText->new($this, wxID_ANY, "In each box move the scroll wheel in the direction it is labelled with:", [0, 90], wxDefaultSize, 0, "");
    $text2->SetFont(Wx::Font->newLong(16, wxFONTFAMILY_DEFAULT, wxFONTSTYLE_NORMAL, wxFONTWEIGHT_MAX, 0));


    my $button4 = Wx::Button->new($this, wxID_ANY, "Scroll\nUp", [200, 120]);
    $button4->SetFont(Wx::Font->newLong(14, wxFONTFAMILY_DEFAULT, wxFONTSTYLE_NORMAL, wxFONTWEIGHT_MAX, 0));
    $button4->SetFocus();
    $button4->SetBackgroundColour($start_background);
    $button4->SetForegroundColour($start_foreground);
    $button4->SetSize(Wx::Size->new(100, 100));
    EVT_MOUSEWHEEL($button4, sub {my ($this, $event) = @_; if($event->GetWheelRotation() > 0) { $button4->SetBackgroundColour($end_background); $button4->SetForegroundColour($end_foreground);} $event->Skip();});

    my $button5 = Wx::Button->new($this, wxID_ANY, "Scroll\nDown", [400, 120]);
    $button5->SetFont(Wx::Font->newLong(14, wxFONTFAMILY_DEFAULT, wxFONTSTYLE_NORMAL, wxFONTWEIGHT_MAX, 0));
    $button5->SetFocus();
    $button5->SetBackgroundColour($start_background);
    $button5->SetForegroundColour($start_foreground);
    $button5->SetSize(Wx::Size->new(100, 100));
    EVT_MOUSEWHEEL($button5, sub {my ($this, $event) = @_; if($event->GetWheelRotation() < 0) { $button5->SetBackgroundColour($end_background); $button5->SetForegroundColour($end_foreground);} $event->Skip();});

    if($main::default_mode eq 'advanced') {
	my $text3 = Wx::StaticText->new($this, wxID_ANY, "Left click in the second box but continue to hold until releasing in the first box:", [0, 220], wxDefaultSize, 0, "");
	$text3->SetFont(Wx::Font->newLong(16, wxFONTFAMILY_DEFAULT, wxFONTSTYLE_NORMAL, wxFONTWEIGHT_MAX, 0));

	my $button6 = Wx::Button->new($this, wxID_ANY, "Drag to and Release Here", [100, 250]);
	$button6->SetFont(Wx::Font->newLong(14, wxFONTFAMILY_DEFAULT, wxFONTSTYLE_NORMAL, wxFONTWEIGHT_MAX, 0));
	$button6->SetFocus();
	$button6->SetBackgroundColour($start_background);
	$button6->SetForegroundColour($start_foreground);
	$button6->SetSize(Wx::Size->new(200, 50));

	my $button7 = Wx::Button->new($this, wxID_ANY, "Click and Hold Here", [400, 250]);
	$button7->SetFont(Wx::Font->newLong(14, wxFONTFAMILY_DEFAULT, wxFONTSTYLE_NORMAL, wxFONTWEIGHT_MAX, 0));
	$button7->SetFocus();
	$button7->SetBackgroundColour($start_background);
	$button7->SetForegroundColour($start_foreground);
	$button7->SetSize(Wx::Size->new(200, 50));
	EVT_LEFT_DOWN($button7, sub {my ($this, $event) = @_; $button7->SetBackgroundColour($end_background); $button7->SetForegroundColour($end_foreground); $event->Skip();});
	EVT_LEFT_UP($button7, sub {my ($this, $event) = @_; my $pos = $event->GetPosition(); if($pos->x >= -300 && $pos->x <= -100 && $pos->y >= 0 && $pos->y <= 50) { $button6->SetBackgroundColour($end_background); $button6->SetForegroundColour($end_foreground); } else { $button7->SetBackgroundColour($start_background); $button7->SetForegroundColour($start_foreground) }; $event->Skip();}  );

	my $text4 = Wx::StaticText->new($this, wxID_ANY, "Do the same here:", [0, 300], wxDefaultSize, 0, "");
	$text4->SetFont(Wx::Font->newLong(16, wxFONTFAMILY_DEFAULT, wxFONTSTYLE_NORMAL, wxFONTWEIGHT_MAX, 0));

	my $button8 = Wx::Button->new($this, wxID_ANY, "Drag to and Release Here", [250, 330]);
	$button8->SetFont(Wx::Font->newLong(14, wxFONTFAMILY_DEFAULT, wxFONTSTYLE_NORMAL, wxFONTWEIGHT_MAX, 0));
	$button8->SetFocus();
	$button8->SetBackgroundColour($start_background);
	$button8->SetForegroundColour($start_foreground);
	$button8->SetSize(Wx::Size->new(200, 50));

	my $button9 = Wx::Button->new($this, wxID_ANY, "Click and Hold Here", [250, 400]);
	$button9->SetFocus();
	$button9->SetFont(Wx::Font->newLong(14, wxFONTFAMILY_DEFAULT, wxFONTSTYLE_NORMAL, wxFONTWEIGHT_MAX, 0));
	$button9->SetBackgroundColour($start_background);
	$button9->SetForegroundColour($start_foreground);
	$button9->SetSize(Wx::Size->new(200, 50));
	EVT_LEFT_DOWN($button9, sub {my ($this, $event) = @_; $button9->SetBackgroundColour($end_background); $button9->SetForegroundColour($end_foreground); $event->Skip();});
	EVT_LEFT_UP($button9, sub {my ($this, $event) = @_; my $pos = $event->GetPosition(); if($pos->x >= 0 && $pos->x <= 200 && $pos->y >= -70 && $pos->y <= -25) { $button8->SetBackgroundColour($end_background); $button8->SetForegroundColour($end_foreground); } else { $button9->SetBackgroundColour($start_background); $button9->SetForegroundColour($start_foreground) }; $event->Skip();}  );
    }

    EVT_PAINT( $this, \&OnPaint );
    EVT_CLOSE( $this, \&OnClose );

    my $text5 = Wx::StaticText->new($this, wxID_ANY, "If the tests passed:\n * clean the mouse\n * neatly rubber band the cord\n * sort it into the appropriate box above", [0, $main::default_mode eq 'advanced' ? 460 : 220], wxDefaultSize, 0, "");
    $text5->SetFont(Wx::Font->newLong(16, wxFONTFAMILY_DEFAULT, wxFONTSTYLE_NORMAL, wxFONTWEIGHT_MAX, 0));

    $this->Show;
    $this->ShowFullScreen(1);
    return $this;
}

sub OnPaint {
    my ($this, $event) = @_;
    my $dc = Wx::PaintDC->new($this);
    if($main::default_mode eq 'advanced') {
	$dc->DrawLine(310, 275, 390, 275);
	$dc->DrawLine(310, 275, 320, 250);
	$dc->DrawLine(310, 275, 320, 300);

	$dc->DrawLine(215, 355, 215, 425);
	$dc->DrawLine(215, 355, 190, 365);
	$dc->DrawLine(215, 355, 240, 365);
    }
    undef $dc;
    return;
}

sub OnClose {
    my( $this, $event ) = @_;
    $this->Destroy;
}

package MyKeyboardWindow;

use Wx qw(wxDefaultSize wxDefaultValidator wxID_ANY);
use Wx::Event qw(EVT_KEY_DOWN EVT_CLOSE EVT_LEFT_DOWN EVT_BUTTON);

use base 'Wx::Frame';
sub colour_from_setting {
    my $name = shift;
    return Wx::Colour->new($main::settings{$name}->{'r'}, $main::settings{$name}->{'g'}, $main::settings{$name}->{'b'});
}

sub start {
    my $class = shift;
    if($main::mainwindow) {
	$main::mainwindow->Destroy();
    }
    $main::mainwindow = $class->new();
    $main::windowtype = "tester";
}

sub Restart {
    @main::found_keycodes = ();
    MyKeyboardWindow->start();
}

sub Settings {
    MyDialog->start(MyKeyboardWindow);
}

sub Mouse {
    MyMouseWindow->start();
}

sub reverse_hash {
    my $hash = shift;
    my $newhash = {};
    foreach(keys %{$hash}) {
	$newhash->{$hash->{$_}} = $_;
    }
    return $newhash;
}

sub new {
    my( $class, $label ) = @_;
    my $this = $class->SUPER::new( undef, -1, "", [-1, -1], [250, 110] );
    my $xmlHash = main::load_xml("profiles", $main::default_profile);
    foreach(@{$xmlHash->{settings}->{setting}}) {
	$main::settings{$_->{'name'}} = $_;
    };
    my $keyboard = main::load_xml("keyboards", $main::default_keyboard);
    @main::keys = @{$keyboard->{keys}->{key}};

#    my $size = Wx::Button::GetDefaultSize;
#    $main::height = $size->GetHeight();
#    $main::width = $size->GetWidth() / 2.0;
    my $total_width = Wx::GetDisplaySize()->GetWidth();
    $main::height = $main::settings{'height'}->{'-content'};
#    $main::width = $main::settings{'width'}->{'-content'};
    my %width_hash = ();
    # determine needed width
    foreach(@main::keys) {
	my $hash = $_;
	$width_hash{$hash->{'row'}} ||= 0;
	$width_hash{$hash->{'row'}} += $hash->{'skip'} if($hash->{'skip'});
	my $multiplier = 1;
	if($hash->{'width'}) {
	    $multiplier = $hash->{'width'};
	}
	$width_hash{$hash->{'row'}} += $multiplier;
    }
    my $needed = @{[reverse(sort(values(%width_hash)))]}[0];
    $main::width = $total_width / $needed;
    %width_hash = ();
    %main::buttons = ();
    my $restart_button = Wx::Button->new($this, wxID_ANY, "Restart", [300, 0]);
    EVT_BUTTON($restart_button, wxID_ANY, \&Restart);
    my $mouse_button = Wx::Button->new($this, wxID_ANY, "Mouse", [0, 0]);
    EVT_BUTTON($mouse_button, wxID_ANY, \&Mouse);
    my $settings_button = Wx::Button->new($this, wxID_ANY, "Settings", [200, 0]);
    EVT_BUTTON($settings_button, wxID_ANY, \&Settings);
    my $quit_button = Wx::Button->new($this, wxID_ANY, "Shut Down", [100, 0]);
    EVT_BUTTON($quit_button, wxID_ANY, sub {$this->OnClose;});
    my $text_keyboard;
    my $text_profile;
    my $text = Wx::StaticText->new($this, wxID_ANY, "Current Keyboard Layout: " . reverse_hash($main::keyboards)->{$main::default_keyboard} . "\nCurrent Display Profile: " . reverse_hash($main::profiles)->{$main::default_profile}, [400, 0], wxDefaultSize, 0, "");
    $text->SetFont(Wx::Font->newLong(16, wxFONTFAMILY_DEFAULT, wxFONTSTYLE_NORMAL, wxFONTWEIGHT_MAX, 0));
    foreach(@main::keys) {
	my $hash = $_;
	$width_hash{$hash->{'row'}} ||= 0;
	$width_hash{$hash->{'row'}} += $main::width * $hash->{'skip'} if($hash->{'skip'});
	my $button = Wx::Button->new($this, wxID_ANY, $hash->{'display'}, [$width_hash{$hash->{'row'}}, (($hash->{'row'} - 1) * $main::height) + 50]);
	$button->SetFocus();
	$button->SetBackgroundColour(colour_from_setting('unpressed_color'));
	$button->SetForegroundColour(colour_from_setting('unpressed_text'));
	$main::buttons{$hash->{'code'}} = $button;
	$main::buttons{$hash->{'alias'}} = $button if($hash->{'alias'}); # TODO: this should be better but works for now
	my $multiplier = 1;
	if($hash->{'width'}) {
	    $multiplier = $hash->{'width'};
	}
	my $v_multiplier = 1; # TODO: this does screw up the width counts, but this doesn't actually matter because all of the long keys are luckily on the far right.
	if($hash->{'height'}) {
	    $v_multiplier = $hash->{'height'};
	}
	$width_hash{$hash->{'row'}} += $main::width * $multiplier;
	$button->SetSize(Wx::Size->new($main::width * $multiplier, $main::height * $v_multiplier));
    }
    EVT_CLOSE( $this, \&OnClose );
    foreach(@main::found_keycodes) {
	main::process_code($_);
    }
    $this->Show;
    $this->ShowFullScreen(1);
    return $this;
}

sub OnClose {
    my( $this, $event ) = @_;
    $this->Destroy;
}

package main;

use Wx qw(wxDefaultSize wxDefaultValidator wxID_ANY);

use strict;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Wx::Event qw(EVT_KEY_DOWN EVT_CLOSE EVT_LEFT_DOWN);

use XML::Mini::Document;

#$XML::Mini::AutoEscapeEntities = 0;

sub keydown {
    my($this, $event) = @_;
    unless($main::windowtype eq "tester") {
	$event->Skip();
	return;
    }
    my $code = $event->GetRawKeyCode();
    process_code($code);
    push @main::found_keycodes, $code unless(grep {$_ == $code} @main::found_keycodes);
}

sub process_code {
    my $code = shift;
    if($main::buttons{$code}) {
	$main::buttons{$code}->SetBackgroundColour(MyKeyboardWindow::colour_from_setting('pressed_color'));
	$main::buttons{$code}->SetForegroundColour(MyKeyboardWindow::colour_from_setting('pressed_text'));
    } else {
	print "Unknown keycode: " . $code . "\n"; # TODO: remove this
    }
}

sub data_file {
    if ( -d File::Spec->catfile($FindBin::Bin, "..", "data") ) {
        return File::Spec->catfile($FindBin::Bin, "..", "data", @_);
    } else {
        return File::Spec->catfile("/usr", "share", "wx-keyboard-tester", @_);
    }
}

sub xml_file {
    my $basename = pop();
    my $f = data_file(@_, $basename . ".xml");
}

sub load_xml {
    my $xmlDoc = XML::Mini::Document->new();
    my $f = join '', @_;
    $f = xml_file(@_) unless $f =~ /\//;
    $xmlDoc->fromFile($f);
    my $xmlHash = $xmlDoc->toHash();
    return $xmlHash;
}

use File::Find::Rule;

sub find_choices {
  my @list = @_;
  my @files = File::Find::Rule->file()
    ->name( '*.xml' )
    ->in( data_file( @_) );
  @files = map {s/^.*\/(.*)\.xml$/$1/; $_} @files;
  my $hash = {};
  foreach(@files) {
      my $title = load_xml(@list, $_)->{'title'};
      $hash->{$title} = $_;
  }
  return $hash;
}

sub mystrip {
    my $str = shift;
    $str = "$str";
    $str =~ s/^\s*//;
    $str =~ s/\s*$//;
    return $str;
}

#use Data::Dumper;

our @found_keycodes = ();

our %buttons = ();
our %settings;
our @keys;
our ($width, $height);
our ($mainwindow);

our $profiles = find_choices("profiles");
our $keyboards = find_choices("keyboards");
our $user_settings_file = $ENV{HOME} . "/.wxKeyboardTester.xml";
our $system_settings_file = "/etc/wxKeyboardTester.xml";
my $settings_hash;
if(-f $user_settings_file) {
    $settings_hash = load_xml($user_settings_file);
} elsif(-f $system_settings_file) {
    $settings_hash = load_xml($system_settings_file);
} else {
    $settings_hash = {};
}
our $default_profile = $settings_hash->{'profile'};
our $default_keyboard = $settings_hash->{'keyboard'};
our $default_mode = $settings_hash->{'mode'} || 'advanced';
grep {$default_profile eq $_} @{[values(%{$profiles})]} or $default_profile = @{[values(%{$profiles})]}[0];
grep {$default_keyboard eq $_} @{[values(%{$keyboards})]} or $default_keyboard = @{[values(%{$keyboards})]}[0];
MyDialog::save_settings();
our $window_type;
my $app = Wx::SimpleApp->new;
EVT_KEY_DOWN($app, \&main::keydown);
if((defined($ENV{'KEYBOARD_TESTER_MODE'}) && ($ENV{'KEYBOARD_TESTER_MODE'} eq 'mouse')) || ((scalar(@ARGV) > 0) && ($ARGV[0] eq '--mouse'))) {
    MyMouseWindow->start();
} else {
    MyKeyboardWindow->start();
}
$app->MainLoop;

