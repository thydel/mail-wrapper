#!/usr/bin/perl -w

=head1 NAME

mail-wrapper.pl - filter input lines for patterns then invoque mail with pattern count in subject

=head1 SYNOPSIS

mail-wrapper.pl [I<options ...>] [I<file ...>]

Options:

=over 8

=item B<--help>

Print a brief help message and exits.

=item B<--subject=>I<subject>

Argument to the B<-s> option of L<mail(1)>.

=item [B<--errorp>=I<regexp> ...]

List of L<perlre(1)> error I<regexp>.

=item [B<--warnp>=I<regexp> ...]

List of L<perlre(1)> warning I<regexp>.

=item [B<--hidep>=I<regexp> ...]

List of L<perlre(1)> I<regexp> to be hidden.

=item [B<--marke>=I<string> ...]

The I<string> used to tag errors in subject line. Default to B<ERROR>

=item [B<--markw>=I<string> ...]

The I<string> used to tag warnings in subject line. Default to B<WARNINGS>

=item [B<--markh>=I<string> ...]

The I<string> used to tag hiddens in subject line. Default to B<HIDDEN>

=item [B<--chiden>=I<number>]

If more than this number of consecutive hidden lines replace lines by B<--markh> value.

=item [B<--mail>|B<--no-mail>]

To L<mail(1)> or not to L<cat(1)>. Use for test regexp. default to B<--mail>.

=item [B<--who>=I<email>]

Whom to send report. Default B<thy@nowhere.tld>.

=back

=head1 DESCRIPTION

B<mail-wrapper.pl> read I<file ...> (default B<STDIN>).

Group of more than B<chiden> lines matching one of B<hidep>
L<perlre(1)> are discarded and replace by a single line marked with
B<markh> followed by the count of discarded lines.

The whole set of undiscarded lines is kept in memory.

Matching B<errorp> and B<warnp> L<perlre(1)> are counted for those
kept lines.

The B<subject> string is prefixed whith a report of B<errorp>,
B<warnp> and B<hidep> count and the kept lines mailed to B<who> using
L<mail(1)>.

=cut

use strict;
use Getopt::Long;
use Pod::Usage;

# wrapper for «sendmail -s $subject $who»
# suppress lines matching one of the «hidep» pattern args
# look for lines matching one of the «errop» pattern args
# prefix $subject with a report of suppressed and error matched lines

#### options

my $help;
my $subject = 'no-subject';
my @errorp;			# error pattern list
my @warnp;			# warn pattern list
my @hidep = ('never-match');	# hide pattern list
my $marke = 'ERROR';		# mark to output in case of error
my $markw = 'WARNING';		# mark to output in case of error
my $markh = 'HIDDEN';		# mark to output in case of hidden lines
my $chiden = 1;			# if more than this number of consecutive hidden lines replace lines by $markh
my $mail = 1;			# mail or cat
my $mailiferror = 0;		# mail if error pattern matched, else cat if not logging
my $mailforwarning = 1;	        # do not mail if warning and no error (still mail if no warning and no error)
                                # to be used as nomailforwarning
my $logfile = '';		# append to logfile (always)
my $who = 'thy@nowhere.tld';	# whom to mail
my $dummy;

GetOptions('help!' => \$help, 'subject=s' => \$subject, 'errorp=s' => \@errorp, 'warnp=s' => \@warnp,
	   'hidep=s' => \@hidep, 'chiden=i' => \$chiden, 'marke=s' => \$marke, 'markw=s' => \$markw, 'markh=s' => \$markh,
	   'mail!' => \$mail, 'mailiferror!' => \$mailiferror, 'mailforwarning!' => \$mailforwarning,
	   'logfile=s' => \$logfile, 'who=s' => \$who, 'dummy' => \$dummy) or pod2usage(2); # die "bad options\n";

pod2usage(-verbose => 2) if ($help);

#### format a hash

sub fmth (\%;$$) { join($_[2] || ', ', map(${$_[0]}{$_} . ' ' . ($_[1] || '"') . $_ . ($_[1] || '"'), keys %{$_[0]})); }

####

my @lines;			# input lines (hidden removed)
my %hiden; 			# hidden pattern count
my %error;			# error pattern count
my %warn;			# warn pattern count

#### fill in lines table skiping those matching one of hide patterns

{
    my $cnt = 0;
    while (<>) {
	my $found;
	for my $hidep (@hidep) {
	    if (/$hidep/) { ++$found; ++$cnt; ++$hiden{$hidep}; last; }
	}
	push @lines, $markh . ' ' . $cnt . "\n" if (!$found or eof) and $cnt > $chiden;
	if (!$found) { push @lines, $_; $cnt = 0; }
    }
}

# to report what was hidden
my $hiden = fmth %hiden;

#### look for errors

for (@lines) { for my $errorp (@errorp) { ++$error{$errorp} if /$errorp/; }}
my $error = fmth %error;

#### look for warning

for (@lines) { for my $warnp (@warnp) { ++$warn{$warnp} if /$warnp/; }}
my $warn = fmth %warn;

#### build subject lines

my $nsubject;

$nsubject = $marke . ': ' . $error if $error;
$nsubject .= '; ' if $error and $warn;
$nsubject = $markw . ': ' . $warn if $warn;
$nsubject .= '; ' if ($error or $warn) and $hiden;
$nsubject .= $markh . ': ' . $hiden if $hiden;
$nsubject .= '; ' if $nsubject;
$nsubject .= $subject;

#### maybe log

if ($logfile) {
    my $pipe = '| H=$(hostname -s) gawk -- \'{print strftime("%c", systime()), ENVIRON["H"], $0}\' >> ' . $logfile;
    open P, $pipe or die $pipe . $!;
    print P $nsubject, "\n";
    for (@lines) { print P; }
}

#### mail if error

$mail = 0 if $mailiferror;
$mail = 0 if (!$mailforwarning and $warn);
$mail = 1 if ($mailiferror and $error);

#### mail or print

if ($mail) {
    $nsubject =~ s/'/\\\'/;	# protect ' againt shell
    my $pipe = '| mail -s $' . '\'' . $nsubject . '\' ' . $who; # need bash
    open P, $pipe or die $pipe . $!;
    for (@lines) { print P; }
} elsif (!$mailiferror and !$logfile) {
    print $nsubject, "\n";
    for (@lines) { print; }
}

exit(0);
