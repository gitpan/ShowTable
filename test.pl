#!/usr/local/bin/perl
#

use ShowTable;
use OutPut;

@Titles = ("Index", "Name", "Phone", "Address");
@Types  = ("int",   "char", "char",  "char");
@Widths = (  5,     20,     15,      50);
@Data   = ( [ 1, "Alan Stebbens", "555-1234", "1234 Something St., CA" ],
	    [ 2, "Bob Frankel",   "555-1235", "9234 Nowhere Way, WA" ],
	    [ 3, "Mr. Goodwrench","555-9432", "1238 Car Lane Pl., NY" ],
	    [ 4, "Mr. Ed",	  "555-3215", "9876 Cowbarn Home, VA" ],
	  );

@subs = qw( ShowTable ShowSimpleTable ShowListTable ShowHTMLTable ShowBoxTable );

@ARGV = (1..99) unless $#ARGV >= 0;

sub test {
    local @titles = @Titles;
    local $theRow;
    my $with;
    foreach $with (qw( with without )) {
	foreach $sub (@subs) {
	    out;
	    out "Testing %s %s titles", $sub, $with;
	    out;
	    &$sub( \@titles, \@Types, \@Widths, 
		sub { &ShowRow( $_[0], \$theRow, \@Data ); });
	}
	@titles = ();
    }
}

test if grep(1 == $_, @ARGV);

@Data = ( [ "Alan", "This is a very long line of text which simulates a text ".
		    "string which is supposed to wrap in its field width." ],
	  [ "Kevin", "This is another long line of text which will also wrap ".
		    "so I can see if this part of ShowTable really works as ".
		    "designed.  If not it's back to the drawing board." ],
	  [ "Toad",  "This is a short line" ],
	  [ "Monica", "This is another short line" ],
	  [ "Stu",   "Finally, here is another long line which shold wrap but ".
		    "maybe not" ],
	);
@Widths = ( 10, 40 );
@Types  = qw( char text );
@Titles = qw( Name Biography );

test if grep(2 == $_, @ARGV);

exit;
