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
    my $button = Wx::Button->new($this, wxID_ANY, "foo");
    $button->SetFocus();
    $button->SetBackgroundColour(colour_from_setting('unpressed_color'));
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
    print "$code\n";
}

sub load_xml {
    my $xmlDoc = XML::Mini::Document->new();
    open my $F, File::Spec->catfile($FindBin::Bin, "..", "data", shift() . ".xml");
    my $XMLString = join '', <$F>;
    $xmlDoc->parse($XMLString);
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
# print Dumper($xmlHash) . "\n";
my $dialog = MyWindow->new();
$dialog->Show;
$app->MainLoop;
