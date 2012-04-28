#!/usr/bin/perl -w

BEGIN {
    eval("use Wx 0.93;");
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

package MyDialog;

use Wx qw(wxDefaultSize wxDefaultValidator wxID_ANY wxDefaultPosition wxICON_ERROR wxFONTFAMILY_DEFAULT wxFONTSTYLE_NORMAL wxFONTWEIGHT_BOLD);
use Wx::Event qw(EVT_KEY_DOWN EVT_CLOSE EVT_LEFT_DOWN EVT_BUTTON);

use base 'Wx::Frame';
sub new {
    my( $class, $label ) = @_;
    my $this = $class->SUPER::new( undef, -1, "", [-1, -1], [250, 110] );
    $this->{'myjunk'} = {};
    my @profiles = ();
    my $i;
    my $i_profiles;
    $i = 0;
    foreach(@{[keys(%{$main::profiles})]}){
	push @profiles, $_;
	$i_profiles = $i if($main::profiles->{$_} eq $main::default_profile);
	$i += 1;
    }
    Wx::StaticText->new($this, wxID_ANY, "Display Profiles:", wxDefaultPosition, wxDefaultSize, 0, "");
    $this->{'myjunk'}->{'profiles'} = Wx::ListBox->new($this, wxID_ANY, [0, 20], [300, 200], \@profiles, 0, wxDefaultValidator, "");
    $this->{'myjunk'}->{'profiles'}->SetSelection($i_profiles);
    my $button = Wx::Button->new($this, wxID_ANY, "OK", [0, 220]);
    EVT_BUTTON($button, wxID_ANY, sub { OnButton($this); });
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
    close $F;
}

sub OnButton {
    my $this = shift;
    $main::default_profile = $main::profiles->{$this->{'myjunk'}->{'profiles'}->GetStringSelection()};
    save_settings();
    MyWindow->start();
    $this->Destroy;
}

sub OnClose {
    my( $this, $event ) = @_;
    $this->Destroy;
}
package MyWindow;

use Wx qw(wxDefaultSize wxDefaultValidator wxID_ANY  wxFONTFAMILY_DEFAULT wxFONTSTYLE_NORMAL wxFONTWEIGHT_BOLD wxFONTWEIGHT_MAX);
use Wx::Event qw(EVT_KEY_DOWN EVT_CLOSE EVT_LEFT_DOWN EVT_BUTTON EVT_LEFT_UP EVT_MIDDLE_UP EVT_RIGHT_UP EVT_MOUSEWHEEL);

use base 'Wx::Frame';

sub start {
    my $class = shift;
    if($main::mainwindow) {
	$main::mainwindow->Destroy();
    }
    $main::mainwindow = $class->new();
    $main::windowtype = "tester";
}

sub Restart {
    MyWindow->start();
}

sub Settings {
    MyDialog->start();
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
    my $restart_button = Wx::Button->new($this, wxID_ANY, "Restart", [400, 0]);
    EVT_BUTTON($restart_button, wxID_ANY, \&Restart);
    my $settings_button = Wx::Button->new($this, wxID_ANY, "Settings", [300, 0]);
    EVT_BUTTON($settings_button, wxID_ANY, \&Settings);
    my $quit_button = Wx::Button->new($this, wxID_ANY, "Shut Down", [200, 0]);
    EVT_BUTTON($quit_button, wxID_ANY, sub {$this->OnClose;});

    my $start_background = colour_from_setting('unpressed_color');
    my $start_foreground = colour_from_setting('unpressed_text');

    my $end_background = colour_from_setting('pressed_color');
    my $end_foreground = colour_from_setting('pressed_text');

    my $text = Wx::StaticText->new($this, wxID_ANY, "Click each box using the mouse button it is labelled with:", [0, 30], wxDefaultSize, 0, "");
    $text->SetFont(Wx::Font->newLong(16, wxFONTFAMILY_DEFAULT, wxFONTSTYLE_NORMAL, wxFONTWEIGHT_MAX, 0));

    my $button = Wx::Button->new($this, wxID_ANY, "Left Click", [100, 60]);
    $button->SetFocus();
    $button->SetBackgroundColour($start_background);
    $button->SetForegroundColour($start_foreground);
    $button->SetSize(Wx::Size->new(100, 30));
    EVT_LEFT_UP($button, sub {my ($this, $event) = @_; $button->SetBackgroundColour($end_background); $button->SetForegroundColour($end_foreground); $event->Skip();});

    my $button2 = Wx::Button->new($this, wxID_ANY, "Middle Click", [300, 60]);
    $button2->SetFocus();
    $button2->SetBackgroundColour($start_background);
    $button2->SetForegroundColour($start_foreground);
    $button2->SetSize(Wx::Size->new(100, 30));
    EVT_MIDDLE_UP($button2, sub {my ($this, $event) = @_; $button2->SetBackgroundColour($end_background); $button2->SetForegroundColour($end_foreground); $event->Skip();});

    my $button3 = Wx::Button->new($this, wxID_ANY, "Right Click", [500, 60]);
    $button3->SetFocus();
    $button3->SetBackgroundColour($start_background);
    $button3->SetForegroundColour($start_foreground);
    $button3->SetSize(Wx::Size->new(100, 30));
    EVT_RIGHT_UP($button3, sub {my ($this, $event) = @_; $button3->SetBackgroundColour($end_background); $button3->SetForegroundColour($end_foreground); $event->Skip();});

    my $text2 = Wx::StaticText->new($this, wxID_ANY, "In each box move the scroll wheel in the direction it is labelled with:", [0, 90], wxDefaultSize, 0, "");
    $text2->SetFont(Wx::Font->newLong(16, wxFONTFAMILY_DEFAULT, wxFONTSTYLE_NORMAL, wxFONTWEIGHT_MAX, 0));


    my $button4 = Wx::Button->new($this, wxID_ANY, "Scroll Up", [200, 120]);
    $button4->SetFocus();
    $button4->SetBackgroundColour($start_background);
    $button4->SetForegroundColour($start_foreground);
    $button4->SetSize(Wx::Size->new(100, 100));
    EVT_MOUSEWHEEL($button4, sub {my ($this, $event) = @_; if($event->GetWheelRotation() > 0) { $button4->SetBackgroundColour($end_background); $button4->SetForegroundColour($end_foreground);} $event->Skip();});

    my $button5 = Wx::Button->new($this, wxID_ANY, "Scroll Down", [400, 120]);
    $button5->SetFocus();
    $button5->SetBackgroundColour($start_background);
    $button5->SetForegroundColour($start_foreground);
    $button5->SetSize(Wx::Size->new(100, 100));
    EVT_MOUSEWHEEL($button5, sub {my ($this, $event) = @_; if($event->GetWheelRotation() < 0) { $button5->SetBackgroundColour($end_background); $button5->SetForegroundColour($end_foreground);} $event->Skip();});

    my $text3 = Wx::StaticText->new($this, wxID_ANY, "Left click in the second box but continue to hold until releasing in the first box:", [0, 220], wxDefaultSize, 0, "");
    $text3->SetFont(Wx::Font->newLong(16, wxFONTFAMILY_DEFAULT, wxFONTSTYLE_NORMAL, wxFONTWEIGHT_MAX, 0));

    my $button6 = Wx::Button->new($this, wxID_ANY, "Drag to and Release Here", [100, 250]);
    $button6->SetFocus();
    $button6->SetBackgroundColour($start_background);
    $button6->SetForegroundColour($start_foreground);
    $button6->SetSize(Wx::Size->new(200, 50));

    my $button7 = Wx::Button->new($this, wxID_ANY, "Click and Hold Here", [400, 250]);
    $button7->SetFocus();
    $button7->SetBackgroundColour($start_background);
    $button7->SetForegroundColour($start_foreground);
    $button7->SetSize(Wx::Size->new(200, 50));
    EVT_LEFT_DOWN($button7, sub {my ($this, $event) = @_; $button7->SetBackgroundColour($end_background); $button7->SetForegroundColour($end_foreground); $event->Skip();});
    EVT_LEFT_UP($button7, sub {my ($this, $event) = @_; my $pos = $event->GetPosition(); if($pos->x >= -300 && $pos->x <= -100 && $pos->y >= 0 && $pos->y <= 50) { $button6->SetBackgroundColour($end_background); $button6->SetForegroundColour($end_foreground); } else { $button7->SetBackgroundColour($start_background); $button7->SetForegroundColour($start_foreground) }; $event->Skip();}  );

    my $text4 = Wx::StaticText->new($this, wxID_ANY, "Do the same here:", [0, 300], wxDefaultSize, 0, "");
    $text4->SetFont(Wx::Font->newLong(16, wxFONTFAMILY_DEFAULT, wxFONTSTYLE_NORMAL, wxFONTWEIGHT_MAX, 0));

    EVT_CLOSE( $this, \&OnClose );
    my $button8 = Wx::Button->new($this, wxID_ANY, "Drag to and Release Here", [250, 330]);
    $button8->SetFocus();
    $button8->SetBackgroundColour($start_background);
    $button8->SetForegroundColour($start_foreground);
    $button8->SetSize(Wx::Size->new(200, 50));

    my $button9 = Wx::Button->new($this, wxID_ANY, "Click and Hold Here", [250, 400]);
    $button9->SetFocus();
    $button9->SetBackgroundColour($start_background);
    $button9->SetForegroundColour($start_foreground);
    $button9->SetSize(Wx::Size->new(200, 50));
    EVT_LEFT_DOWN($button9, sub {my ($this, $event) = @_; $button9->SetBackgroundColour($end_background); $button9->SetForegroundColour($end_foreground); $event->Skip();});
    EVT_LEFT_UP($button9, sub {my ($this, $event) = @_; my $pos = $event->GetPosition(); if($pos->x >= 0 && $pos->x <= 200 && $pos->y >= -70 && $pos->y <= -25) { $button8->SetBackgroundColour($end_background); $button8->SetForegroundColour($end_foreground); } else { $button9->SetBackgroundColour($start_background); $button9->SetForegroundColour($start_foreground) }; $event->Skip();}  );

    $this->Show;
    $this->ShowFullScreen(1);
    return $this;
}

sub OnClose {
    my( $this, $event ) = @_;
    $this->Destroy;
}

package main;

use XML::Mini::Document;
use strict;
use FindBin;

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
use Wx qw(wxDefaultSize wxDefaultValidator wxID_ANY);

use strict;

use Wx::Event qw(EVT_KEY_DOWN EVT_CLOSE EVT_LEFT_DOWN);

our $profiles = find_choices("profiles");
our $user_settings_file = $ENV{HOME} . "/.wxMouseTester.xml";
our $system_settings_file = "/etc/wxMouseTester.xml";
my $settings_hash;
if(-f $user_settings_file) {
    $settings_hash = load_xml($user_settings_file);
} elsif(-f $system_settings_file) {
    $settings_hash = load_xml($system_settings_file);
} else {
    $settings_hash = {};
}
our $default_profile = $settings_hash->{'profile'};
grep {$default_profile eq $_} @{[values(%{$profiles})]} or $default_profile = @{[values(%{$profiles})]}[0];
MyDialog::save_settings();
our $window_type;
my $app = Wx::SimpleApp->new;
MyWindow->start();
$app->MainLoop;

