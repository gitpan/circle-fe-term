#  You may distribute under the terms of the GNU General Public License
#
#  (C) Paul Evans, 2010 -- leonerd@leonerd.org.uk

package Circle::FE::Term::Widget::Entry;

use strict;
use constant type => "Entry";

sub build
{
   my $class = shift;
   my ( $obj, $tab ) = @_;

   my $autoclear = $obj->prop("autoclear");

   my $history_index;

   my $widget = Circle::FE::Term::Widget::Entry::Widget->new(
      tab => $tab,

      on_enter => sub {
         my ( $self, $line ) = @_;

         $obj->call_method(
            method => "enter",
            args => [ $self->text ],

            on_result => sub {}, # IGNORE

            on_error => sub {
               my ( $message ) = @_;
               # TODO: write the error message somewhere
            },
         );

         $self->set_text( "" ) if $autoclear;
         undef $history_index;
      },
   );

   $obj->watch_property(
      property => "text",
      on_set => sub {
         my ( $text ) = @_;
         $text = "" unless defined $text;
         $widget->set_text( $text );
      },
      want_initial => 1,
   );

   $obj->watch_property(
      property => "history",
      on_updated => sub {}, # We ignore this, we just want a local cache
      want_initial => 1,
   );

   $widget->bind_keys(
      Up => sub {
         my $widget = shift;

         my $history = $obj->prop("history");
         if( !defined $history_index ) {
            return 1 unless @$history;
            $history_index = $#$history;
         }
         elsif( $history_index == 0 ) {
            # Don't move
            return 1;
         }
         else {
            $history_index--;
         }

         my $line = $history->[$history_index];
         $widget->set_text( $line );
         $widget->set_position( length( $line ) ); # TODO: accept negative

         return 1;
      },
      Down => sub {
         my $widget = shift;

         my $history = $obj->prop("history");
         return 1 unless defined $history_index;
         if( $history_index < $#$history ) {
            $history_index++;
         }
         else {
            $widget->set_text( "" );
            undef $history_index;
            return 1;
         }

         my $line = $history->[$history_index];
         $widget->set_text( $line );
         $widget->set_position( length( $line ) );

         return 1;
      },
   );

   return $widget;
}

package Circle::FE::Term::Widget::Entry::Widget;

use base qw( Tickit::Widget::Entry );

sub new
{
   my $class = shift;
   my %args = @_;

   my $tab = delete $args{tab};

   my $self = $class->SUPER::new( %args );

   $self->{tab} = $tab;

   return $self;
}

sub on_key
{
   my $self = shift;
   $self->{tab}->activated;

   $self->SUPER::on_key( @_ );
}

0x55AA;
