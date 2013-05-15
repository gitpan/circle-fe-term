#  You may distribute under the terms of the GNU General Public License
#
#  (C) Paul Evans, 2010-2013 -- leonerd@leonerd.org.uk

package Circle::FE::Term::Widget::Scroller;

use strict;
use feature qw( switch );
use constant type => "Scroller";

use Circle::FE::Term;

use Convert::Color 0.06;
use Convert::Color::XTerm;
use POSIX qw( strftime );
use String::Tagged;
use Text::Balanced qw( extract_bracketed );
use Tangence::ObjectProxy '0.16'; # watch with iterators

# Guess that we can do 256 colours on xterm or any -256color terminal
my $AS_TERM = ( $ENV{TERM} eq "xterm" or $ENV{TERM} =~ m/-256color$/ ) ? "as_xterm" : "as_vga";

sub build
{
   my $class = shift;
   my ( $obj, $tab ) = @_;

   my $widget = Circle::FE::Term::Widget::Scroller::Widget->new(
      classes => $obj->prop( "classes" ),
      gravity => "bottom",
   );

   my $self = bless {
      tab    => $tab,
      widget => $widget,
      last_datestamp => "",
      last_datestamp_top => "",
   };

   # Fetch in chunks of the height of the window, so the first chunk looks instant
   my $chunksize = $tab->widget->window->lines;
   my $iter;
   my $idx;
   my $on_iter_more;

   $obj->watch_property(
      property => "displayevents",
      iter_from => "last",
      on_iter => sub {
         ( $iter, undef, my $max ) = @_;

         $on_iter_more = sub {
            ( $idx, my @more ) = @_;
            $self->insert_event( top => $_ ) for reverse @more;

            my $remaining = $idx;
            $remaining = $chunksize if $remaining > $chunksize;

            if( $remaining ) {
               $iter->next_backward( count => $remaining, on_more => $on_iter_more );
            }
            else {
               undef $iter;
               undef $on_iter_more;
            }
         };

         $on_iter_more->( $max + 1, () );
      },
      on_set => sub {
         die "This should not happen\n";
      },
      on_push => sub {
         $self->insert_event( bottom => $_ ) for @_;
      },
      on_shift => sub {
         my ( $count ) = @_;
         $count -= $idx;
         $widget->shift( $count ) if $count > 0;
      },
   );

   return $widget;
}

sub insert_event
{
   my $self = shift;
   my ( $end, $ev ) = @_;

   my ( $event, $time, $args ) = @$ev;

   my $tab = $self->{tab};

   my @time = localtime( $time );

   my $datestamp = strftime( Circle::FE::Term->get_theme_var( "datestamp" ), @time );
   my $timestamp = strftime( Circle::FE::Term->get_theme_var( "timestamp" ), @time );

   my $format = Circle::FE::Term->get_theme_var( $event );
   defined $format or $format = "No format defined for event $event";

   my @items = ( $self->format_event( $timestamp . $format, $args ) );

   my $widget = $self->{widget};
   given( $end ) {
      when( "bottom" ) {
         unshift @items, $self->format_event( Circle::FE::Term->get_theme_var( "datemessage" ), { datestamp => $datestamp } )
            if $datestamp ne $self->{last_datestamp};

         $widget->push( @items );
         $self->{last_datestamp} = $datestamp;
      }
      when( "top" ) {
         push @items, $self->format_event( Circle::FE::Term->get_theme_var( "datemessage" ), { datestamp => $self->{last_datestamp_top} } )
            if $datestamp ne $self->{last_datestamp_top} and length $self->{last_datestamp_top};

         $widget->unshift( @items );
         $self->{last_datestamp_top} = $datestamp;
         $self->{last_datestamp} = $datestamp if !length $self->{last_datestamp};
      }
   }
}

sub format_event
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

   return Tickit::Widget::Scroller::Item::RichText->new( $str, indent => $indent );
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
Tickit::Widget::Scroller->VERSION( 0.10 ); # ->unshift
use Tickit::Widget::Scroller::Item::RichText;

sub new
{
   my $class = shift;
   return $class->SUPER::new( @_,
      gen_bottom_indicator => "gen_bottom_indicator"
   );
}

sub clear_lines
{
   my $self = shift;

   undef @{ $self->{lines} };

   my $window = $self->window or return;
   $window->clear;
   $window->restore;
}

sub push
{
   my $self = shift;
   my $below_before = $self->lines_below;
   $self->SUPER::push( @_ );
   if( $below_before ) {
      $self->{more_count} += $self->lines_below - $below_before;
      $self->update_indicators;
   }
}

sub gen_bottom_indicator
{
   my $self = shift;
   my $below = $self->lines_below;
   if( !$below ) {
      undef $self->{more_count};
      return;
   }

   if( $self->{more_count} ) {
      return sprintf "-- +%d [%d more] --", $below - $self->{more_count}, $self->{more_count};
   }
   else {
      return sprintf "-- +%d --", $below;
   }
}

0x55AA;
