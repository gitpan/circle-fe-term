use strict;
use warnings;

use Module::Build;

my $build = Module::Build->new(
   module_name => 'Circle::FE::Term',
   dist_name   => 'circle-fe-term',
   requires => {
      'Convert::Color' => '0.06',
      'Convert::Color::XTerm' => 0,
      'IO::Async' => '0.14',
      'Net::Async::Tangence::Client' => '0.08',
      'String::Tagged' => 0,
      'Tangence::ObjectProxy' => '0.18',
      'Text::Balanced' => 0,
      'Tickit' => '0.37', # Tickit::Style allows '::'
      'Tickit::Async' => 0,
      'Tickit::Term' => '0.27',
      'Tickit::Widget::Entry' => '0.20',
      'Tickit::Widget::HBox' => '0.32',
      'Tickit::Widget::Scroller' => '0.10',
      'Tickit::Widget::Tabbed' => '0.008',
      'Tickit::Widget::VBox' => '0.31',
   },
   auto_configure_requires => 0, # Don't add M::B to configure_requires
   share_dir => {
      dist => "share",
   },
   license => 'perl',
   create_makefile_pl => 'traditional',
   create_license => 1,
   create_readme  => 1,
);

$build->create_build_script;
