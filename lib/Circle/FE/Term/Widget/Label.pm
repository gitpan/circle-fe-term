#  You may distribute under the terms of the GNU General Public License
#
#  (C) Paul Evans, 2011 -- leonerd@leonerd.org.uk

package Circle::FE::Term::Widget::Label;

use strict;
use warnings;

use constant type => "Label";

use Tickit::Widget::Static;

sub build
{
   my $class = shift;
   my ( $obj, $tab ) = @_;

   my $widget = Tickit::Widget::Static->new( text => "" );
   $obj->watch_property(
      property => "text",
      on_set   => sub { $widget->set_text( $_[0] ) },
      want_initial => 1,
   );

   return $widget;
}

1;
