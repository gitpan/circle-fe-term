package Circle::FE::Term::Ribbon;

use strict;
use warnings;

use base qw( Tickit::Widget::Tabbed::Ribbon );

package Circle::FE::Term::Ribbon::horizontal;
use base qw( Circle::FE::Term::Ribbon );

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

      $win->print( $printed = sprintf ":%s |", $active->label );
      $col += textwidth $printed;
   }

   if( grep { $_ != $active and $_->level > 0 } @tabs ) {
      $win->print( " [", $self->activity_pen );
      $col += 2;

      my $first = 1;

      foreach my $idx ( 0 .. $#tabs ) {
         my $tab = $tabs[$idx];
         next if $tab == $active;

         next if $tab->level == 0;

         if( !$first ) {
            $win->print( ",", $self->activity_pen );
            $col++;
         }

         my $label = sprintf "%d:%s", $idx + 1, $tab->label;
         $win->print( $label, $tab->pen );
         $col += textwidth $label;

         $first = 0;
      }

      $win->print( "]", $self->activity_pen );
      $col++;
   }

   my $rhs = sprintf "| total: %d", scalar @tabs;

   if( ( my $spare = $win->cols - $col - textwidth $rhs ) > 0 ) {
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

1;
