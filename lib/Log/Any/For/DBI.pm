package Log::Any::For::DBI;

use 5.010;
use strict;
use warnings;
use Log::Any '$log';

# VERSION

use DBI;
use Log::Any::For::Class qw(add_logging_to_class);
use Scalar::Util qw(blessed);

sub _precall_logger {
    my $args = shift;
    my $name = $args->{name};
    my $margs = $args->{args};

    # mask connect password
    if ($name =~ /\A(DBI(?:::db)?::connect\w*)\z/) {
        $margs->[3] = "********";
    }

    Log::Any::For::Class::_default_precall_logger($args);
}

sub _postcall_logger {
    my $args = shift;

    Log::Any::For::Class::_default_postcall_logger($args);
}

sub import {

    # I put it in $doit in case we need to add more classes from inside $logger,
    # e.g. DBD::*, etc.
    my $doit;
    $doit = sub {
        my @classes = @_;

        add_logging_to_class(
            classes => \@classes,
            precall_logger => \&_precall_logger,
            postcall_logger => \&_postcall_logger,
            filter_methods => sub {
                local $_ = shift;
                return unless
                    /\A(
                         DBI::\w+|
                         DBI::db::\w+|
                         DBI::st::\w+
                     )\z/x;
                return if
                    /\A(
                         (\w+::)+[_A-Z]\w+|
                         DBI::(?:install|setup)\w+|
                         DBI::db::clone|
                         DBI::trace\w*
                     )\z/x;
                1;
            },
        );
    };

    $doit->("DBI", "DBI::db", "DBI::st");
}

1;
# ABSTRACT: Add logging to DBI method calls, etc

=head1 SYNOPSIS

 use DBI;
 use Log::Any::For::DBI;

 # now all connect()'s, do()'s, prepare()'s are logged with Log::Any
 my $dbh = DBI->connect("dbi:...", $user, $pass);
 $dbh->do("INSERT INTO table VALUES (...)");

Sample script and output:

 % TRACE=1 perl -MLog::Any::App -MDBI -MLog::Any::For::DBI \
   -e'$dbh=DBI->connect("dbi:SQLite:dbname=/tmp/tmp.db", "", "");
   $dbh->do("CREATE TABLE IF NOT EXISTS t (i INTEGER)");'
 [1] ---> DBI::connect(['dbi:SQLite:dbname=/tmp/tmp.db','','********'])
 [5] <--- DBI::connect() = [bless( {}, 'DBI::db' )]
 [5] ---> DBI::db::do(['CREATE TABLE IF NOT EXISTS t (i INTEGER)'])
 [5] ---> DBI::db::prepare(['CREATE TABLE IF NOT EXISTS t (i INTEGER)',undef])
 [5] <--- DBI::db::prepare() = [bless( {}, 'DBI::st' )]
 [5] ---> DBI::st::execute([])
 [5] <--- DBI::st::execute() = ['0E0']
 [5] <--- DBI::db::do()


=head1 SEE ALSO

L<Log::Any::For::Class>

L<DBIx::Log4perl>, one of the inspirations for this module. With due respect to
its author, I didn't like the approach of DBIx::Log4perl and its intricate links
to DBI's internals. I'm sure DBIx::Log4perl is good at what it does, but
currently I only need to log SQL statements.

=cut
