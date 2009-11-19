#!/usr/bin/perl -w

BEGIN {
    eval("use Wx 0.92;"); # TODO: switch this back to 0.93
    if($@) {
	die("Requires Wx perl module (latest from CPAN or Debian Sid)");
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

use CGI;

*XML::Mini::escapeEntities = sub {
    my $class = shift;
    my $toencode = shift;
    
    return undef unless (defined $toencode);

    $toencode = CGI::unescapeHTML($toencode);
    return $toencode;
};

package MyDialog;

use Wx qw(wxDefaultSize wxDefaultValidator wxID_ANY wxDefaultPosition wxICON_ERROR);
use Wx::Event qw(EVT_KEY_DOWN EVT_CLOSE EVT_LEFT_DOWN EVT_BUTTON);

use base 'Wx::Frame';
sub new {
    my( $class, $label ) = @_;
    my $this = $class->SUPER::new( undef, -1, "", [-1, -1], [250, 110] );
    $this->{'myjunk'} = {};
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
    $this->{'myjunk'}->{'profiles'}->SetSelection($i_profiles);
    $this->{'myjunk'}->{'keyboards'}->SetSelection($i_keyboards);
    my $button = Wx::Button->new($this, wxID_ANY, "OK", [0, 440]);
    EVT_BUTTON($button, wxID_ANY, sub { OnButton($this); });
    my $a_button = Wx::Button->new($this, wxID_ANY, "Admin", [0, 480]);
    EVT_BUTTON($a_button, wxID_ANY, sub { OnAdmin($this); });
    EVT_CLOSE( $this, \&OnClose );
    $this->Show;
    $this->ShowFullScreen(1);
    return $this;
}

sub start {
    my $class = shift;
    if($main::mainwindow) {
	$main::mainwindow->Destroy();
    }
    $main::mainwindow = $class->new();
    $main::windowtype = "settings";
}

sub save_settings {
    open my $F, ">", $main::user_settings_file;
    print $F "<profile>" . $main::default_profile . "</profile>\n";
    print $F "<keyboard>" . $main::default_keyboard . "</keyboard>\n";
    close $F;
}

sub OnAdmin {
    my $this = shift;
    my $res = Wx::GetPasswordFromUser("What's the admin password?", "Enter password", "", $this);
    if($res eq "4321") {
	system("touch /tmp/wx-keyboard-tester.disabled");
	system("reboot");
	$this->Destroy;
    } else {
	Wx::MessageBox("Incorrect password", "", wxICON_ERROR, $this);
    }
}

sub OnButton {
    my $this = shift;
    $main::default_profile = $main::profiles->{$this->{'myjunk'}->{'profiles'}->GetStringSelection()};
    $main::default_keyboard = $main::keyboards->{$this->{'myjunk'}->{'keyboards'}->GetStringSelection()};
    save_settings();
    MyWindow->start();
    $this->Destroy;
}

sub OnClose {
    my( $this, $event ) = @_;
    $this->Destroy;
}

package MyWindow;

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
    MyWindow->start();
}

sub Settings {
    MyDialog->start();
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
    my $restart_button = Wx::Button->new($this, wxID_ANY, "Restart", [0, 0]);
    EVT_BUTTON($restart_button, wxID_ANY, \&Restart);
    my $settings_button = Wx::Button->new($this, wxID_ANY, "Settings", [100, 0]);
    EVT_BUTTON($settings_button, wxID_ANY, \&Settings);
    my $quit_button = Wx::Button->new($this, wxID_ANY, "Quit", [200, 0]);
    EVT_BUTTON($quit_button, wxID_ANY, sub {$this->OnClose;});
    my $text_keyboard;
    my $text_profile;
    Wx::StaticText->new($this, wxID_ANY, "Current Keyboard Layout: " . reverse_hash($main::keyboards)->{$main::default_keyboard} . "\nCurrent Display Profile: " . reverse_hash($main::profiles)->{$main::default_profile}, [300, 0], wxDefaultSize, 0, "");
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
	$main::buttons{$code}->SetBackgroundColour(MyWindow::colour_from_setting('pressed_color'));
	$main::buttons{$code}->SetForegroundColour(MyWindow::colour_from_setting('pressed_text'));
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
grep {$default_profile eq $_} @{[values(%{$profiles})]} or $default_profile = @{[values(%{$profiles})]}[0];
grep {$default_keyboard eq $_} @{[values(%{$keyboards})]} or $default_keyboard = @{[values(%{$keyboards})]}[0];
MyDialog::save_settings();
our $window_type;
my $app = Wx::SimpleApp->new;
EVT_KEY_DOWN($app, \&main::keydown);
MyWindow->start();
$app->MainLoop;

