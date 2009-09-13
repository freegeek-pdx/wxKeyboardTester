#!/usr/bin/perl -w

BEGIN {
    eval("require Wx;");
    if($@) {
	die("Requires Wx perl module (from CPAN or libwx-perl package)");
    }
    eval("require XML::Mini::Document;");
    if($@) {
	die("Requires XML::Mini::Document perl module (from CPAN or libxml-mini-perl package)");
    }
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
	$main::buttons{$hash->{'code'}} = $button;
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
if(!Wx::KeyEvent->new(0)->can('GetRawKeyCode')) {
    die("Needs wxperl from pkg-perl SVN or wxperl SVN");
}

use strict;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Wx::Event qw(EVT_KEY_DOWN EVT_CLOSE EVT_LEFT_DOWN);

use XML::Mini::Document;

sub keydown {
    my($this, $event) = @_;
    my $code = $event->GetRawKeyCode();
    if($main::buttons{$code}) {
	$main::buttons{$code}->SetBackgroundColour(MyWindow::colour_from_setting('pressed_color'));
    } else {
	print "Unknown keycode: " . $code . "\n";
    }
}

sub load_xml {
    my $xmlDoc = XML::Mini::Document->new();
    my $basename = pop();
    my $f = File::Spec->catfile($FindBin::Bin, "..", "data", @_, $basename . ".xml");
    $xmlDoc->fromFile($f);
    my $xmlHash = $xmlDoc->toHash();
    return $xmlHash;
}

sub mystrip {
    my $str = shift;
    $str = "$str";
    $str =~ s/^\s*//;
    $str =~ s/\s*$//;
    return $str;
}

#use Data::Dumper;

my $app = Wx::SimpleApp->new;
EVT_KEY_DOWN($app, \&main::keydown);
my $xmlHash = load_xml("settings");
our %settings = ();
foreach(@{$xmlHash->{settings}->{setting}}) {
    $settings{$_->{'name'}} = $_;
};
my $keyboard = load_xml("keyboards", "ryan52");
our @keys = @{$keyboard->{keys}->{key}};
our %buttons = ();

my $size = Wx::Button::GetDefaultSize; # wxDefaultSize
our $height = $size->GetHeight(); # TODO: get from settings
our $width = $size->GetWidth() / 2.0; # TODO: get from settings

# print Dumper($xmlHash) . "\n";
my $dialog = MyWindow->new();
$dialog->Show;
$app->MainLoop;
