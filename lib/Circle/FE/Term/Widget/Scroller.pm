#  You may distribute under the terms of the GNU General Public License
#
#  (C) Paul Evans, 2010-2012 -- leonerd@leonerd.org.uk

package Circle::FE::Term::Widget::Scroller;

use strict;
use constant type => "Scroller";

use Circle::FE::Term;

use Convert::Color 0.06;
use Convert::Color::XTerm;
use POSIX qw( strftime );
use String::Tagged;
use Text::Balanced qw( extract_bracketed );

# Guess that we can do 256 colours on xterm or any -256color terminal
my $AS_TERM = ( $ENV{TERM} eq "xterm" or $ENV{TERM} =~ m/-256color$/ ) ? "as_xterm" : "as_vga";

sub build
{
   my $class = shift;
   my ( $obj, $tab ) = @_;

   my $widget = Circle::FE::Term::Widget::Scroller::Widget->new( gravity => "bottom" );

   my $self = bless {
      tab    => $tab,
      widget => $widget,
      last_datestamp => "",
   };

   $obj->watch_property(
      property => "displayevents",
      on_set => sub {
         $widget->clear_lines;
         $widget->freeze_updates;
         $self->append_event( $_ ) for @{ $_[0] };
         $widget->thaw_updates;
         $widget->scroll_to_bottom;
      },
      on_push => sub {
         $self->append_event( $_ ) for @_;
      },
      on_shift => sub {
         $widget->shift( $_[0] );
      },
      want_initial => 1,
   );

   return $widget;
}

sub append_event
{
   my $self = shift;
   my ( $ev ) = @_;

   my ( $event, $time, $args ) = @$ev;

   my $tab = $self->{tab};

   my @time = localtime( $time );

   my $datestamp = strftime( Circle::FE::Term->get_theme_var( "datestamp" ), @time );
   my $timestamp = strftime( Circle::FE::Term->get_theme_var( "timestamp" ), @time );

   if( $datestamp ne $self->{last_datestamp} ) {
      $self->append_formatted( Circle::FE::Term->get_theme_var( "datemessage" ), { datestamp => $datestamp } );
      $self->{last_datestamp} = $datestamp;
   }

   my $format = Circle::FE::Term->get_theme_var( $event );
   defined $format or $format = "No format defined for event $event";

   $self->append_formatted( $timestamp . $format, $args );
}

sub append_formatted
{
   my $self = shift;
   my ( $format, $args ) = @_;

   my $str = String::Tagged->new();
   $self->_apply_formatting( $format, $args, $str );

   my $indent = 4;
   if( grep { $_ eq "indent" } $str->tagnames and 
       my $extent = $str->get_tag_missing_extent( 0, "indent" ) ) {
      # TODO: Should use textwidth not just char. count
      $indent = $extent->end;
   }

   my $widget = $self->{widget};
   $widget->push( Tickit::Widget::Scroller::Item::RichText->new( $str, indent => $indent ) );
}

my %colourcache;
sub _convert_colour
{
   my $self = shift;
   my ( $colspec ) = @_;

   return undef if !defined $colspec;

   return $colourcache{$colspec} ||= sub {
      return Convert::Color->new( "rgb8:$1$1$2$2$3$3" )->$AS_TERM->index if $colspec =~ m/^#([0-9A-F])([0-9A-F])([0-9A-F])$/i;
      return Convert::Color->new( "rgb8:$1$2$3" )->$AS_TERM->index if $colspec =~ m/^#([0-9A-F]{2})([0-9A-F]{2})([0-9A-F]{2})$/i;
      return Convert::Color->new( "vga:$colspec" )->index if $colspec =~ m/^[a-z]+$/;

      print STDERR "TODO: Unknown colour spec $colspec\n";
      6; # TODO
   }->();
}

sub _apply_formatting
{
   my $self = shift;
   my ( $format, $args, $str ) = @_;

   while( length $format ) {
      if( $format =~ s/^\$(\w+)// ) {
         my $val = exists $args->{$1} ? $args->{$1} : "<No such variable $1>";
         defined $val or $val = "<Variable $1 is not defined>";

         my @parts = ref $val eq "ARRAY" ? @$val : ( $val );

         foreach my $part ( @parts ) {
            my ( $text, %format ) = ref $part eq "ARRAY" ? @$part : ( $part );

            # Tickit::Widget::Scroller::Item::Text doesn't like C0, C1 or DEL
            # control characters. Replace them with U+FFFD
            $text =~ s/[\x00-\x1f\x80-\x9f\x7f]/\x{fffd}/g;

            foreach (qw( fg bg )) {
               defined $format{$_} or next;
               $format{$_} = $self->_convert_colour( Circle::FE::Term->translate_theme_colour( $format{$_} ) );
            }

            $str->append_tagged( $text, %format );
         }
      }
      elsif( $format =~ m/^\{/ ) {
         my $piece = extract_bracketed( $format, "{}" );
         s/^{//, s/}$// for $piece;

         if( $piece =~ m/ / ) {
            my ( $code, $content ) = split( m/ /, $piece, 2 );

            my ( $type, $arg ) = split( m/:/, $code, 2 );

            my $start = length $str->str;

            $self->_apply_formatting( $content, $args, $str );

            my $end = length $str->str;

            $arg = $self->_convert_colour( $arg ) if $type eq "fg" or $type eq "bg";
            $str->apply_tag( $start, $end - $start, $type => $arg );
         }
         else {
            $self->_apply_formatting( $piece, $args, $str );
         }
      }
      else {
         $format =~ s/^([^\$\{]+)//;
         my $val = $1;
         $str->append( $val );
      }
   }
}

package Circle::FE::Term::Widget::Scroller::Widget;

use base qw( Tickit::Widget::Scroller );
Tickit::Widget::Scroller->VERSION( 0.04 );
use Tickit::Widget::Scroller::Item::RichText;

sub clear_lines
{
   my $self = shift;

   undef @{ $self->{lines} };

   my $window = $self->window or return;
   $window->clear;
   $window->restore;
}

sub freeze_updates
{
   my $self = shift;
   $self->{frozen} = 1;
}

sub thaw_updates
{
   my $self = shift;
   $self->{frozen} = 0;
   $self->redraw if $self->{need_redraw}--;
}

0x55AA;
