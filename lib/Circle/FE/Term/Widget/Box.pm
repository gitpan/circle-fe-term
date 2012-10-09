#  You may distribute under the terms of the GNU General Public License
#
#  (C) Paul Evans, 2010-2011 -- leonerd@leonerd.org.uk

package Circle::FE::Term::Widget::Box;

use strict;
use constant type => "Box";

use Tickit::Widget::HBox;
use Tickit::Widget::VBox;

sub build
{
   my $class = shift;
   my ( $obj, $tab ) = @_;

   my $orientation = $obj->prop("orientation");
   my $widget;
   if( $orientation eq "vertical" ) {
      $widget = Tickit::Widget::VBox->new;
   }
   elsif( $orientation eq "horizontal" ) {
      $widget = Tickit::Widget::HBox->new( spacing => 1, bg => 4 );
   }
   else {
      die "Unrecognised orientation '$orientation'";
   }

   foreach my $c ( @{ $obj->prop("children") } ) {
      if( $c->{child} ) {
         my $childwidget = $tab->build_widget( $c->{child} );
         $widget->add( $childwidget, expand => $c->{expand} );
      }
      else {
         # Just add spacing
         $widget->add( Tickit::Widget::Static->new( text => " " ), expand => 1 );
      }
   }

   return $widget;
}

0x55AA;
