#  You may distribute under the terms of the GNU General Public License
#
#  (C) Paul Evans, 2012 -- leonerd@leonerd.org.uk

package Circle::FE::Term::Ribbon;

use strict;
use warnings;

use base qw( Tickit::Widget::Tabbed::Ribbon );

package Circle::FE::Term::Ribbon::horizontal;
use base qw( Circle::FE::Term::Ribbon );

use feature qw( switch );

use Tickit::Utils qw( textwidth );
use List::Util qw( max first );

use Tickit::WidgetRole::Penable name => "activity", default => { fg => "cyan" };

sub new
{
   my $class = shift;
   my $self = $class->SUPER::new( @_ );

   $self->_init_activity_pen;

   return $self;
}

sub lines { 1 }
sub cols  { 1 }

sub render
{
   my $self = shift;
   my %args = @_;

   my $win = $self->window or return;

   my @tabs = $self->tabs;
   my $active = $self->active_tab;

   $win->goto( 0, 0 );

   my $col = 0;
   my $printed;

   if( $active ) {
      $win->print( $printed = $active->index + 1, $active->pen );
      $col += textwidth $printed;

      $win->print( $printed = sprintf ":%s | ", $active->label );
      $col += textwidth $printed;
   }

   my $rhs = sprintf " | total: %d", scalar @tabs;
   my $rhswidth = textwidth $rhs;

   if( grep { $_ != $active and $_->level > 0 } @tabs ) {
      my @used;
      # Output formats: [0] = full text
      #                 [1] = initialise level<2 names
      #                 [2] = initialise level<3 names
      #                 [3] = initialise all names
      #                 [4] = hide level<2 names, initialise others
      #                 [5] = hide all names

      foreach my $idx ( 0 .. $#tabs ) {
         my $tab = $tabs[$idx];
         next if $tab == $active;

         next unless my $level = $tab->level;

         my $width_full    = textwidth sprintf "%d:%s", $idx + 1, $tab->label;
         my $width_short = textwidth sprintf "%d:%s", $idx + 1, $tab->label_short;
         my $width_hide   = textwidth sprintf "%d", $idx + 1;

         $used[0] += 1 +              $width_full;
         $used[1] += 1 + $level < 2 ? $width_short : $width_full;
         $used[2] += 1 + $level < 3 ? $width_short : $width_full;
         $used[3] += 1 +              $width_short;
         $used[4] += 1 + $level < 2 ? $width_hide : $width_short;
         $used[5] += 1 +              $width_hide;
      }

      my $space = $win->cols - $col - $rhswidth;

      my $format = 0;
      $format++ while $used[$format] > $space;

      my $first = 1;

      TAB: foreach my $idx ( 0 .. $#tabs ) {
         my $tab = $tabs[$idx];
         next if $tab == $active;

         next unless my $level = $tab->level;

         my $label;
         
         for( $format ) {
            $label =             sprintf "%d:%s", $idx + 1, $tab->label;
            when( 0 ) { ; }
            when( 1 ) { $label = sprintf "%d:%s", $idx + 1, $tab->label_short if $level < 2 }
            when( 2 ) { $label = sprintf "%d:%s", $idx + 1, $tab->label_short if $level < 3 }
            $label =             sprintf "%d:%s", $idx + 1, $tab->label_short;
            when( 3 ) { ; }
            when( 4 ) { $label = sprintf "%d", $idx + 1 if $level < 3 }
            when( 5 ) { $label = sprintf "%d", $idx + 1 }
         }

         if( !$first ) {
            $win->print( ",", $self->activity_pen );
            $col++;
         }

         $win->print( $label, $tab->pen );
         $col += textwidth $label;

         $first = 0;
      }
   }

   if( ( my $spare = $win->cols - $col - $rhswidth ) > 0 ) {
      $win->erasech( $spare, 1 );
   }

   $win->print( $rhs );
}

sub scroll_to_visible { }

sub activate_next
{
   my $self = shift;

   my @tabs = $self->tabs;
   @tabs = ( @tabs[$self->active_tab_index + 1 .. $#tabs], @tabs[0 .. $self->active_tab_index - 1] );

   my $max_level = max map { $_->level } @tabs;
   return unless $max_level > 0;

   my $next_tab = first { $_->level == $max_level } @tabs;

   $next_tab->activate if $next_tab;
}

my $tab_shortcuts = "1234567890" .
                    "qwertyuiop" .
                    "sdfghjkl;'" .
                    "zxcvbnm,./";

sub on_key
{
   my $self = shift;
   my ( $type, $str ) = @_;

   if( $type eq "key" and $str eq "M-a" ) {
      $self->activate_next;
      return 1;
   }
   elsif( $type eq "key" and $str =~ m/^M-(.)$/ and
          ( my $idx = index $tab_shortcuts, $1 ) > -1 ) {
      $self->activate_tab( $idx );
      return 1;
   }

   return 0;
}

0x55AA;
