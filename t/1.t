#!/usr/bin/perl -w
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl 1.t'

#########################
use strict;

use Test::More tests => 140;

BEGIN { use_ok('POE::Component::Enc::Ogg') };

use POE;
use File::Copy;

my $TEST_MISSING      = 't/missing.wav';
my $TEST_INPUT        = 't/test.wav';
my $TEST_INPUT_COPY   = 't/test2.wav';
my $TEST_OUTPUT       = 't/test.ogg';
my $TEST_OUTPUT_COPY  = 't/test_2.ogg';

unlink $TEST_OUTPUT;

#########################

my ($encoder1, $encoder2, $encoder3, $encoder4, $encoder5);

#########################
# Check construction with defaults
my %defaults = (
    parent    => 'main',
    priority  => 0,
    quality   => 3,
    status    => 'status',
    error     => 'error',
    done      => 'done',
    warning   => 'warning',
    );

$encoder1 = POE::Component::Enc::Ogg->new();
ok ( $encoder1->isa('POE::Component::Enc::Ogg'), 'it\'s an encoder' );
can_ok( $encoder1, qw(enc) );

foreach (keys %defaults) {
    is ( $encoder1->{$_}, $defaults{$_}, $_ . ' default' );
    }

#########################
# Check construction with arguments
my %params = (
    parent    => 'mySession',
    priority  => 1,
    quality   => 10,
    status    => 'cb_status',
    error     => 'cb_error',
    done      => 'cb_done',
    warning   => 'cb_warning',
    album     => 'Flood',
    genre     => 'Alternative',
    );
my %params2 = (
    parent    => 'mySession',
    priority  => 10,
    quality   => 88,
    status    => 'cb_status',
    error     => 'cb_error',
    done      => 'cb_done',
    warning   => 'cb_warning',
    album     => 'An Album',
    genre     => 'A Genre',
    delete    => 1,
    output    => $TEST_OUTPUT_COPY,
    );

$encoder2 = POE::Component::Enc::Ogg->new(%params);
isa_ok ( $encoder2, 'POE::Component::Enc::Ogg');

foreach (keys %params) {
    is ( $encoder2->{$_}, $params{$_}, '# ' . $_ . ' parameter' );
    }

$encoder3 = POE::Component::Enc::Ogg->new(%params);
isa_ok ( $encoder3, 'POE::Component::Enc::Ogg');
$encoder4 = POE::Component::Enc::Ogg->new(%params);
isa_ok ( $encoder4, 'POE::Component::Enc::Ogg');
$encoder5 = POE::Component::Enc::Ogg->new(%params2);
isa_ok ( $encoder5, 'POE::Component::Enc::Ogg');


my $main = POE::Session->create
  ( inline_states =>
      { _start           => \&main_start,
        _stop            => \&main_stop,
        $params{status}  => \&handle_status,
        $params{error}   => \&handle_error,
        $params{done}    => \&handle_done,
        $params{warning} => \&handle_warning,
      }
  );


POE::Kernel->run();

my %expect;

sub main_start
  {
  my ($heap, $kernel) = @_[HEAP, KERNEL];

  POE::Kernel->alias_set($params{parent});

  diag "Start encoder 4 with no input\n";
  push @{$expect{$encoder4}}, 'error:256;no input:';
  $encoder4->enc();

  diag "Start encoder 2 with missing input $TEST_MISSING\n";
  push @{$expect{$encoder2}}, 'error:256;cannot open:';
  $encoder2->enc( input=>$TEST_MISSING );

  SKIP :
    {
    skip "Need the executable 'oggenc'", 110 unless have_encoder();

    diag "Start encoder 3 with $TEST_INPUT\n";
    push @{$expect{$encoder3}}, "status:$TEST_INPUT;$TEST_OUTPUT;[0-9]+\.[0-9]:+";
    push @{$expect{$encoder3}}, "done:$TEST_INPUT;$TEST_OUTPUT:";
    $encoder3->enc( input=>$TEST_INPUT );

    copy($TEST_INPUT, $TEST_INPUT_COPY);

    diag "Start encoder 5 with invalid quality level\n";
    push @{$expect{$encoder5}}, 'warning:too high:';
    push @{$expect{$encoder5}}, 'status::+';
    push @{$expect{$encoder5}}, "done:$TEST_INPUT_COPY;$TEST_OUTPUT_COPY:";
    $encoder5->enc( input       => $TEST_INPUT_COPY,
                    comment     => [
                                    'artist=An Artist',
                                    'tag1=Tag 1',
                                    'tag2=Tag 2',
                                    'title=A Title',
                                   ],
                    date        => 'A Date',
                    tracknumber => 'A Tracknum',
                  );
    }

  }

sub have_encoder
    {
    1 if (-x '/usr/bin/oggenc' || -x '/usr/local/bin/oggenc')
    or diag "Did not find executable /usr/bin/oggenc or /usr/local/bin/oggenc";
    }

sub have_ogginfo
    {
    1 if (-x '/usr/bin/ogginfo' || -x '/usr/local/bin/ogginfo')
    or diag "Did not find executable /usr/bin/ogginfo or /usr/local/bin/ogginfo";
    }

sub main_stop
  {
  SKIP :
    {
    skip "'oggenc' is not an executable", 3 unless have_encoder();

    ok( (-f $TEST_OUTPUT), '# output file created');
    ok( (-f $TEST_OUTPUT_COPY), '# output file created');
    ok( (!-f $TEST_INPUT_COPY), '# input file deleted');
    }

  SKIP :
    {
    skip "Need the executable 'ogginfo'", 8 unless have_ogginfo();

    open INFO, "ogginfo $TEST_OUTPUT_COPY|"
        or die "Cannot start ogginfo $TEST_OUTPUT_COPY: $!";

    while (<INFO>) {
        if (/(\S+)\s*=\s*(.+)/)
            {
            ($1 eq 'title')       && cmp_ok($2, 'eq', 'A Title');
            ($1 eq 'tracknumber') && cmp_ok($2, 'eq', 'A Tracknum');
            ($1 eq 'date')        && cmp_ok($2, 'eq', 'A Date');
            ($1 eq 'artist')      && cmp_ok($2, 'eq', 'An Artist');
            ($1 eq 'comment')     && cmp_ok($2, 'eq', 'A Comment');
            ($1 eq 'genre')       && cmp_ok($2, 'eq', 'A Genre');
            ($1 eq 'album')       && cmp_ok($2, 'eq', 'An Album');
            ($1 eq 'tag1')        && cmp_ok($2, 'eq', 'Tag 1');
            ($1 eq 'tag2')        && cmp_ok($2, 'eq', 'Tag 2');
            }
        }
    close INFO;
    }

  unlink $TEST_OUTPUT;
  unlink $TEST_OUTPUT_COPY;
  }

sub ok_expecting
  {
  my ($from, $sent, $arg) = @_;
  my $expected  = shift @{$expect{$from}} || 'nothing';
  my $expected2 = shift @{$expect{$from}} || 'nothing';

  my @exp=split /:/,$expected;  my ($exp,  $exparg,  $expmany)  = @exp;
     @exp=split /:/,$expected2; my ($exp2, $exparg2, $expmany2) = @exp;

  #diag "got $sent(" . ($arg||'') . ") from $from; expecting $expected or $expected2\n";

  like ($sent, qr/$exp|$exp2/);
  $exparg2 |= '';
  like ($arg, qr/$exparg|$exparg2/i) if ($exparg);

  unshift @{$expect{$from}}, $expected2 unless ($expected2 eq 'nothing');
  if ($expmany) { unshift @{$expect{$from}}, $expected; }
  }

sub handle_error {
  ok_expecting($_[ARG0], 'error', join ';', $_[ARG3], $_[ARG4]);
  }

sub handle_status {
  cmp_ok($_[ARG1], 'ne', undef, 'status handler ARG1 is defined');
  cmp_ok($_[ARG2], 'ne', undef, 'status handler ARG2 is defined');
  ok_expecting($_[ARG0], 'status', join ';',$_[ARG1],$_[ARG2],$_[ARG3]);
}

sub handle_done {
  cmp_ok($_[ARG1], 'ne', undef, 'done handler ARG1 is defined');
  cmp_ok($_[ARG2], 'ne', undef, 'done handler ARG2 is defined');
  ok_expecting($_[ARG0], 'done', join ';',$_[ARG1],$_[ARG2]);
}

sub handle_warning {
  cmp_ok($_[ARG1], 'ne', undef, 'warning handler ARG1 is defined');
  cmp_ok($_[ARG2], 'ne', undef, 'warning handler ARG2 is defined');
  ok_expecting($_[ARG0], 'warning', $_[ARG3]);
}
