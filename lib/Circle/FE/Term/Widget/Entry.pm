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

   my $prehistory;
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

   $obj->watch_property(
      property => "completions",
      on_updated => sub {}, # We ignore this, we just want a local cache
      want_initial => 1,
   );

   $widget->bind_keys(
      Up => sub {
         my $widget = shift;

         my $history = $obj->prop("history");
         if( !defined $history_index ) {
            $prehistory = $widget->text;
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
            $widget->set_text( $prehistory );
            undef $history_index;
            return 1;
         }

         my $line = $history->[$history_index];
         $widget->set_text( $line );
         $widget->set_position( length( $line ) );

         return 1;
      },
      Tab => sub {
         my $widget = shift;
         $widget->tab_complete;
      },
   );

   $widget->{obj} = $obj;

   return $widget;
}

package Circle::FE::Term::Widget::Entry::Widget;

use base qw( Tickit::Widget::Entry );

use Tickit::Utils qw( textwidth );
use List::Util qw( max );

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

   my $redo_tab_complete;
   if( my $popup = delete $self->{tab_complete_popup} ) {
      $popup->hide;
      $redo_tab_complete++
   }

   my $ret = $self->SUPER::on_key( @_ );

   if( $redo_tab_complete and $_[0] eq "text" ) {
      $self->tab_complete;
   }

   return $ret;
}

sub tab_complete
{
   my $widget = shift;

   my $obj = $widget->{obj};

   my ( $partial ) = substr( $widget->text, 0, $widget->position ) =~ m/(\S*)$/;
   my $plen = length $partial;

   my $at_sol = ( $widget->position - $plen ) == 0;

   my @matches;
   my $matchgroup;
   foreach my $group ( values %{ $obj->prop("completions") } ) {
      next if $group->prop("only_at_sol") and not $at_sol;

      my @more = grep { $_ =~ m/^\Q$partial\E/i } @{ $group->prop("items") };

      push @matches, @more;
      $matchgroup = $group if @more;
   }

   return unless @matches;

   my $add = $matches[0];
   foreach my $more ( @matches[1..$#matches] ) {
      # Find the common prefix
      my $diffpos = 1;
      $diffpos++ while lc substr( $add, 0, $diffpos ) eq lc substr( $more, 0, $diffpos );

      return if $diffpos == 1;

      $add = substr( $add, 0, $diffpos - 1 );
   }

   if( @matches == 1 ) {
      # No others meaning only one initially
      $add .= ( $matchgroup->prop("suffix_sol") and $at_sol ) ? $matchgroup->prop("suffix_sol")
                                                              : " ";
   }

   $widget->text_splice( $widget->position - $plen, $plen, $add );

   if( @matches > 1 ) {
      # Split matches on next letter
      my %next;
      foreach ( @matches ) {
         my $l = substr( $_, $plen, 1 );
         push @{ $next{$l} }, $_;
      }

      my @possibles = map {
         @{ $next{$_} } == 1 ? $next{$_}[0]
                             : substr( $next{$_}[0], 0, $plen + 1 )."..."
      } sort keys %next;

      # TODO: Wrap these into a flow

      # TODO: need scrolloffs
      my $popup = $widget->window->make_popup(
         -(scalar @possibles), $widget->position - $widget->{scrolloffs_co} - $plen,
         scalar @possibles, max( map { textwidth($_) } @possibles ),
      );

      $popup->pen->chattrs({ bg => 'green', fg => 'black' });

      $popup->set_on_expose( sub {
         my $win = shift;
         foreach my $line ( 0 .. $#possibles ) {
            $win->goto( $line, 0 );
            my $col = 0;
            $col += $win->print( substr( $possibles[$line], 0, $plen + 1 ), u => 1 )->columns;
            $col += $win->print( substr( $possibles[$line], $plen + 1 ) )->columns;
            $win->erasech( $win->cols - $col );
         }
      } );

      $popup->show;

      $widget->{tab_complete_popup} = $popup;
   }
}

0x55AA;
