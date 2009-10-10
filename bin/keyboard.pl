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

use CGI;

*XML::Mini::escapeEntities = sub {
    my $class = shift;
    my $toencode = shift;
    
    return undef unless (defined $toencode);

    $toencode = CGI::unescapeHTML($toencode);
    return $toencode;
};

package MyDialog;

use Wx qw(wxDefaultSize wxDefaultValidator wxID_ANY);
use Wx::Event qw(EVT_KEY_DOWN EVT_CLOSE EVT_LEFT_DOWN EVT_BUTTON);

use base 'Wx::Frame';
sub new {
    my( $class, $label ) = @_;
    my $this = $class->SUPER::new( undef, -1, "", [-1, -1], [250, 110] );
    my $button = Wx::Button->new($this, wxID_ANY, "OK");
    EVT_BUTTON($button, wxID_ANY, sub { OnButton($this); });
    EVT_CLOSE( $this, \&OnClose );
    return $this;
}

sub OnButton {
    my $this = shift;
    open my $F, ">", main::xml_file("settings");
    print $F "<profile>" . $main::default_profile . "</profile>\n";
    print $F "<keyboard>" . $main::default_keyboard . "</keyboard>\n";
    close $F;

    my $xmlHash = main::load_xml("profiles", $main::default_profile);
    foreach(@{$xmlHash->{settings}->{setting}}) {
	$main::settings{$_->{'name'}} = $_;
    };
    my $keyboard = main::load_xml("keyboards", $main::default_keyboard);
    @main::keys = @{$keyboard->{keys}->{key}};

    my $size = Wx::Button::GetDefaultSize; # wxDefaultSize
    $main::height = $size->GetHeight(); # TODO: get from settings
    $main::width = $size->GetWidth() / 2.0; # TODO: get from settings

    my $dialog = MyWindow->new();
    $dialog->Show;
    $dialog->ShowFullScreen(1);
    $this->Destroy;
}

sub OnClose {
    my( $this, $event ) = @_;
    $this->Destroy;
}

package MyWindow;

use Wx qw(wxDefaultSize wxDefaultValidator wxID_ANY);
use Wx::Event qw(EVT_KEY_DOWN EVT_CLOSE EVT_LEFT_DOWN);

use base 'Wx::Frame';
sub colour_from_setting {
    my $name = shift;
    return Wx::Colour->new($main::settings{$name}->{'r'}, $main::settings{$name}->{'g'}, $main::settings{$name}->{'b'});
}

sub new {
    my( $class, $label ) = @_;
    my $this = $class->SUPER::new( undef, -1, "", [-1, -1], [250, 110] );
    my %width_hash = ();
    foreach(@main::keys) {
	my $hash = $_;
	$width_hash{$hash->{'row'}} ||= 0;
	$width_hash{$hash->{'row'}} += $main::width * $hash->{'skip'} if($hash->{'skip'});
	my $button = Wx::Button->new($this, wxID_ANY, $hash->{'display'}, [$width_hash{$hash->{'row'}}, ($hash->{'row'} - 1) * $main::height]);
	$button->SetFocus();
	$button->SetBackgroundColour(colour_from_setting('unpressed_color'));
	$button->SetForegroundColour(colour_from_setting('unpressed_text'));
	$main::buttons{$hash->{'code'}} = $button;
	$main::buttons{$hash->{'alias'}} = $button if($hash->{'alias'}); # TODO: this should be better but works for now
	my $multiplier = 1;
	if($hash->{'width'}) {
	    $multiplier = $hash->{'width'};
	}
	$width_hash{$hash->{'row'}} += $main::width * $multiplier;
	$button->SetSize(Wx::Size->new($main::width * $multiplier, $main::height));
    }
    EVT_CLOSE( $this, \&OnClose );
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
    my $code = $event->GetRawKeyCode();
    if($main::buttons{$code}) {
	$main::buttons{$code}->SetBackgroundColour(MyWindow::colour_from_setting('pressed_color'));
	$main::buttons{$code}->SetForegroundColour(MyWindow::colour_from_setting('pressed_text'));
    } else {
	print "Unknown keycode: " . $code . "\n";
    }
}

sub xml_file {
    my $basename = pop();
    my $f = File::Spec->catfile($FindBin::Bin, "..", "data", @_, $basename . ".xml");
}

sub load_xml {
    my $xmlDoc = XML::Mini::Document->new();
    my $f = xml_file(@_);
    $xmlDoc->fromFile($f);
    my $xmlHash = $xmlDoc->toHash();
    return $xmlHash;
}

use File::Find::Rule;

sub find_choices {
  my @list = @_;
  my @files = File::Find::Rule->file()
    ->name( '*.xml' )
    ->in( File::Spec->catfile($FindBin::Bin, "..", "data", @_) );
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

our %buttons = ();
our %settings;
our @keys;
our ($width, $height);

our $profiles = find_choices("profiles");
our $keyboards = find_choices("keyboards");
my $settings_hash = load_xml("settings");
our $default_profile = $settings_hash->{'profile'};
our $default_keyboard = $settings_hash->{'keyboard'};

my $app = Wx::SimpleApp->new;
EVT_KEY_DOWN($app, \&main::keydown);
my $dialog = MyDialog->new();
$dialog->Show;
$dialog->ShowFullScreen(1);
$app->MainLoop;

# TODO: right here prompt the user with a list of all of the keys of $profiles and $keyboards, then find the values of their choices in the hash and set $default_

