#!/usr/local/bin/perl
use warnings;
use strict;
use Encode;
use Number::Format qw(format_number);
use Pod::Usage;
use Unicode::UCD qw(charinfo);

pod2usage(-verbose => 2) unless @ARGV && @ARGV == grep { -f } @ARGV;
my $format = @ARGV == 1 ? "%s: %s\n\n" : "%s: %s: %s\n\n" ;
my $files = @ARGV;

binmode STDOUT, ':utf8';

while (<>) {
	### The line number must be stored here because charinfo will botch it.
	my $line_num = $.;
	### Trim the ends of the line.
	s/(?:\A\s+|\s+\z)//g;
	### Attempt initial decode.
	eval { $_ = decode_utf8($_, Encode::FB_CROAK); };
	print 'Invalid UTF-8 @ line ' . format_number($line_num) . ": $_\n\n" and next if $@;
	### Print the details when a UTF-8 pattern matched. See the POD for more info.
	printf $format, format_number($line_num), ($files == 1 ? () : $ARGV), $_ if
		s{
			(
				(?:[\x{c2}-\x{df}][\x{80}-\x{bf}])+ |
				(?:\x{e0}[\x{a0}-\x{bf}][\x{80}-\x{bf}])+ |
				(?:[\x{e1}-\x{ec}][\x{80}-\x{bf}]{2})+ |
				(?:\x{ed}[\x{80}-\x{9f}][\x{80}-\x{bf}])+ |
				(?:[\x{ee}-\x{ef}][\x{80}-\x{bf}]{2})+ |
				(?:\x{f0}[\x{90}-\x{bf}][\x{80}-\x{bf}]{2})+ |
				(?:[\x{f1}-\x{f3}][\x{80}-\x{bf}]{3})+ |
				(?:\x{f4}[\x{80}-\x{8f}][\x{80}-\x{bf}]{2})+
			)
		}{
			my $encoded = 0;
			my $str = $1;
			my $old_str = '';
			### Decode as much as possible.
			while (1) {
				### Save it. We'll fall back to this
				### when the final decoding fails.
				$old_str = $str;
				### The string's UTF-8 flag must be removed so
				### Perl will attempt to decode it again.
				utf8::downgrade($str);
				eval { $str = decode_utf8($str, Encode::FB_CROAK); };
				$str = $old_str and last if $@;
				++$encoded;
			};
			my $info = charinfo(ord $str);
			"[$1]===[$encoded]===[" . $info->{code} . '-' . $info->{name} . ']'
		}gex;
}
continue {
	### Required to reset line numbers when files change within <>.
	close ARGV if eof ARGV;
}

__END__

=head1 NAME

show_multi_utf8.pl

=head1 SYNOPSIS

show_multi_utf8.pl file(s)

=head1 DESCRIPTION

This script is used to report UTF-8 characters that have been (erroneously) encoded multiple times; it does B<not> modify files.

It accepts multiple file names on the command line, loops through each file, decodes the UTF-8, looks for UTF-8 patterns within the decoded string, and continually decodes the pattern until (hopefully) the true UTF-8 encoding is reached. Warnings will be printed if the line contains malformed UTF-8.

It then prints the line number, ":", the file name and ":" (if multiple files are being searched), and the (left and right trimmed) line. In place of the original UTF-8 pattern the following format is shown: "[A]===[B]===[C-D]". A is the original, multi-encoded UTF-8; B the number of times it was encoded; and C and D represent the code point and Unicode name of what the UTF-8 eventually resolved to after being fully decoded.

Note: UTF-8 ranges were taken from "Some Properties of UTF-8", p. 300, Unicode Explained (First Edition).
