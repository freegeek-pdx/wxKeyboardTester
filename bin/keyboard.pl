#!/usr/bin/perl -w

package MyWindow;

use Wx qw(wxDefaultSize wxDefaultValidator wxID_ANY);
use Wx::Event qw(EVT_KEY_DOWN EVT_CLOSE EVT_LEFT_DOWN);

use base 'Wx::Frame';
sub new {
    my( $class, $label ) = @_;
    my $this = $class->SUPER::new( undef, -1, "", [-1, -1], [250, 110] );
    my $button = Wx::Button->new($this, wxID_ANY, "foo");
    $button->SetFocus();
    EVT_CLOSE( $this, \&OnClose );
    return $this;
}

sub OnClose {
    my( $this, $event ) = @_;
    $this->Destroy;
}

package main;

use Wx::Event qw(EVT_KEY_DOWN EVT_CLOSE EVT_LEFT_DOWN);

sub keydown {
    my($this, $event) = @_;
    my $code = $event->GetRawKeyCode();
    print "$code\n";
}

my $app = Wx::SimpleApp->new;
EVT_KEY_DOWN($app, \&main::keydown);
my $dialog = MyWindow->new();
$dialog->Show;
$app->MainLoop;
