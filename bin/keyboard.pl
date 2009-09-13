#!/usr/bin/perl -w

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
    my $i = 0;
    foreach(keys %main::keys) {
	my $hash = $main::keys{$_};
	my $button = Wx::Button->new($this, wxID_ANY, $hash->{'display'}, [0, $i]);
	$i += 50;
	$button->SetFocus();
	$button->SetBackgroundColour(colour_from_setting('unpressed_color'));
	$main::buttons{$hash->{'code'}} = $button;
    }
    EVT_CLOSE( $this, \&OnClose );
    return $this;
}

sub OnClose {
    my( $this, $event ) = @_;
    $this->Destroy;
}

package main;

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

use Data::Dumper;

my $app = Wx::SimpleApp->new;
EVT_KEY_DOWN($app, \&main::keydown);
my $xmlHash = load_xml("settings");
our %settings = ();
foreach(@{$xmlHash->{settings}->{setting}}) {
    $settings{$_->{'name'}} = $_;
};
our %keys = ();
my $keyboard = load_xml("keyboards", "ryan52");
foreach(@{$keyboard->{keys}->{key}}) {
    $keys{$_->{'code'}} = $_;
};
our %buttons = ();
# print Dumper($xmlHash) . "\n";
my $dialog = MyWindow->new();
$dialog->Show;
$app->MainLoop;
