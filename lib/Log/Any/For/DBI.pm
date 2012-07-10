package Log::Any::For::DBI;

use 5.010;
use strict;
use warnings;
use Log::Any '$log';

# VERSION

use Log::Any::For::Class qw(add_logging_to_class);
use Scalar::Util qw(blessed);

sub import {
    my $logger = sub {
        my ($which, %args) = @_;
        my $name = $args{name};

        if ($which eq 'precall') {
            my $margs = $args{args};

            # exclude self or package
            shift @$margs;

            # mask connect password
            if ($name =~ /\A(DBI::connect\w*)\z/) {
                $margs->[2] = "********";
            }

            $log->tracef("-> %s(%s)", $name, $margs);
        } else {
            $log->tracef("<- %s() = %s", $name, $args{result});
        }
    };

    # I put it in $doit in case we need to add more classes from inside $doit,
    # e.g. DBD::*, etc.
    my $doit;
    $doit = sub {
        my @classes = @_;

        add_logging_to_class(
            classes => \@classes,
            precall_logger => sub { $logger->('precall', @_) },
            postcall_logger => sub { $logger->('postcall', @_) },
            filter_methods =>
                qr/\A(
                       DBI::(connect|connect_cached)|
                       DBI::db::(do|prepare|select\w+)|
                       DBI::st::(execute|bind\w+)
                   )\z/x,
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


=head1 SEE ALSO

L<Log::Any::For::Class>

L<DBIx::Log4perl>, one of the inspirations for this module. With due respect to
its author, I didn't like the approach of DBIx::Log4perl and its intricate links
to DBI's internals. I'm sure DBIx::Log4perl is good at what it does, but
currently I only need to log SQL statements.

=cut
