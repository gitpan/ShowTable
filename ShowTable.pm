# perl -w
# ShowTable.pm
#
# $Id: ShowTable.pm,v 1.12 1996/02/29 11:09:38 aks Exp $
#

package ShowTable;

=head1 MODULE

B<ShowTable> - routines to display tabular data in several formats.

=head1 USAGE

C<  use ShowTable;>

=head1 DESCRIPTION

The B<ShowTable> module provides subroutines to display tabular data,
typially from a database, in nicely formatted columns, in several formats.
The output format for any one invocation can be one of four possible styles:

=over 10

=item Box

A tabular format, with the column titles and the entire table surrounded by a
"box" of "C<+>", "C<->", and "C<|>" characters.  See L<"ShowBoxTable"> for details.

=item Table

A simple tabular format, with columns automatically aligned, with column titles.
See L<"ShowSimpleTable">.

=item List

A I<list> style, where columns of data are listed as a I<name>:I<value> pair, one
pair per line, with rows being one or more column values, separated by an empty line.
See L<"ShowListTable">.

=item HTML

The data is output as an HTML I<TABLE>, suitable for display through a I<Web>-client.
See L<"ShowHTMLTable">.

=back

The subroutines which perform these displays are listed below.

=head1 EXPORTED NAMES

This module exports the following subroutines: 

 ShowDatabases	  - show list of databases
 ShowTables	  - show list of tables
 ShowColumns	  - show table of column info
 ShowTable	  - show a table of data
 ShowRow	  - show a row from one or more columns
 ShowTableValue   - show a single column's value
 ShowBoxTable	  - show a table of data in a box
 ShowListTable	  - show a table of data in a list
 ShowSimpleTable  - show a table of data in a simple table
 ShowHTMLTable	  - show a table of data using HTML

All of these subroutines, and others, are described in detail in the
following sections.

=cut

use Exporter;

@ISA = qw( Exporter );
@EXPORT = qw(	ShowDatabases 
		ShowTables 
		ShowColumns 
		ShowTable 
		ShowRow 
		ShowBoxTable 
		ShowHTMLTable 
		ShowListTable
		ShowSimpleTable 
		Show_Mode
		URL_Keys 
	    );

# Some control variables -- the user may set these

$Show_Mode        = 'Box';	# one of: List, Table, Box, or HTML
$List_Wrap_Margin = 10;		# break words up to this long
$Term_Columns     = 80;

%URL_Keys = ();

use Carp;
use OutPut;

unshift(@INC, '.');

sub ShowDatabases;
sub ShowTables;
sub ShowColumns;
sub ShowTable;
sub ShowRow;

sub center;
sub max_length;
sub max;

=head1 MODULES

=head1 ShowTable 

Format and display the contents of one or more rows of data.

C<  B<ShowTable> \@titles, \@types, \@widths, \&row_sub [, \&fmt_sub ];>

C<  $ShowTable::B<Show_Mode> = 'mode';>

C<  $ShowTable::B<Term_Columns> = NNN;>

The C<ShowTable> subroutine displays tabular data aligned in columns,
with headers.  C<ShowTable> supports four I<modes> of display: B<Box>, B<Table>,
B<List>, and B<HTML>.  Each mode is described separately below.

The arguments to C<ShowTable> are:

=over 10

=item C<\@I<titles>>

A reference to an array of column names, or titles.  If a particular column name
is null, then the string C<Column I<num>> is used by default.  To have a column
have no title, use the empty string.

=item C<\@I<types>>

A reference to an array of types, one for each column.  These types are passed to
the I<fmt_sub> for appropriate formatting.  Also, if a column type matches
the regexp "C</text|char|string/i>", then the column alignment will be left-justified,
otherwise it will be right-justified.

=item C<\@I<widths>>

A reference to an array of column widths, which may be given as an integer, or
as a string of the form: C<"I<width>.I<precision>">.

=item C<\&I<row_sub>>

A reference to a subroutine which successively returns rows of values in an array.
It is called for two purposes, each described separately:

* To fetch successive rows of data:

    @row = &$row_sub(0);

When given a null, zero, or empty argument, the next row is returned.

* To initialize or rewind the data traversal.

    $rewindable = &$row_sub(1);

When invoked with a non-null argument, the subroutine should rewind its
row pointer to start at the first row of data.  If the data which
I<row_sub> is traversing is not rewindable, it must return zero or null.
If the data is rewindable, a non-null, non-zero value should be returned.

The I<row_sub> must expect to be invoked once with a non-null argument,
in order to discover whether or not the data is rewindable.  If the data
cannot be rewound, I<row_sub> will thereafter only be called with a zero
argument. 

Specifically, I<row_sub> subroutine is used in this manner:

    $rewindable = &$row_sub(1);
    if ($rewindable) {
	while ((@row = &$row_sub(0)), $#row >= 0) {
	    # examine lengths for optimal formatting
	}
	&$row_sub(1);	# rewind
    }
    while ((@row = &$row_sub(0)), $#row >= 0) {
	# format the data
    }

The consequence of data that is not rewindable, a reasonably nice table
will still be formatted, but it may contain fairly large amounts of
whitespace for wide columns.

=item C<\&I<fmt_sub>>

A reference to a subroutine which formats a value, according to its type, width,
precision, and the current column width.  It is invoked this way:

    $string = &fmt_sub($value, $type, $max_width, $width, $precision)

The C<$I<max_width>> is the maximum width for the column currently being
formatted.

If C<$width> is omitted, C<$max_width> is assumed.

If C<$precision> is omitted, zero is assumed.

If C<\&I<fmt_sub>> is omitted, then a default subroutine, C<ShowTableValue>, 
will be used, which will use Perl's standard string formatting rules.

=back

=cut

sub ShowTable {
    local($_) = $Show_Mode;
    if    (/List/i) 	{ &ShowListTable(@_); }
    elsif (/HTML/i)	{ &ShowHTMLTable(@_); }
    elsif (/Table/i) 	{ &ShowSimpleTable(@_);  }
    else  		{ &ShowBoxTable(@_); }
}

=head1 ShowRow 

Fetch rows successively from one or more columns of data.

C<  B<ShowRow> $rewindflag, \$index, $col_array_1 [, $col_array_2, ...;]>

The B<ShowRow> subroutine returns a row of data from one or more
columns of data.  It is designed to be used as a I<callback> routine,
within the B<ShowTable> routine.   It can be used to select elements
from one or more array reference arguments.

If passed two or more array references as arguments, elements of the
arrays selected by I<$index> are returned as the "row" of data.

If a single array argument is passed, and each element of the array is
itself an array, the subarray is returned as the "row" of data.

If the I<$rewindflag> flag is set, then the I<$index> pointer is reset
to zero, and "true" is returned (a scalar 1).  This indicates that the
data is rewindable to the B<ShowTable> routines.

When the I<$rewindflag> is not set, then the current row of data, as
determined by I<$index> is returned, and I<$index> will
have been incremented.

An actual invocation (from B<ShowColumns>) is:

  ShowTable \@titles, \@types, \@lengths, 
      sub { &ShowRow( $_[0], \$current_row, $col_names, $col_types,
		      $col_lengths, \@col_attrs); };

In the example above, after each invocation, the C<$I<current_row>> argument 
will have been incremented.

=cut

sub ShowRow {
    my $rewind_flag = shift;
    my $index_ref = shift;		# an indirect index
    my @columns = @_;			# get rest of columns
    my @row;				# we're selecting a row
    if ($rewind_flag) {
	$$index_ref = 0;		# reset the pointer
	return 1;
    }
    return undef if $#{$columns[0]} < $$index_ref;
    if ($#columns == 0) {		# exactly one array ref argument
	my $data = $columns[0]->[$$index_ref];	# get the current data
	if (ref($data) eq 'ARRAY') {	# if an array..
	    @row = @$data;		# ..return the array of data
	} elsif (ref($data) eq 'HASH') {# if a hash..
	    @row = values %$data;	# ..return the values 
	} else {			# otherwise..
	    @row = ($data);		# ..return the data element
	}
    } else {				# with two or more array refs..
	my $col;			# select elements from each
	for ($col = 0; $col <= $#columns; $col++) {
	    push(@row, ${$columns[$col]}[$$index_ref]);
	}
    }
    ${$index_ref}++;			# increment the index for the next call
    @row;				# return this row of data
}

=head1 ShowDatabases 

Show a list of database names.

C<  B<ShowDatabases> \@dbnames;>

B<ShowDatabases> is intended to be used to display a list of database
names, under the column heading of "Databases".  It is a special case
usage of B<ShowTable>.

The argument, C<\@I<dbnames>>, is a reference to an array of strings.

=cut

sub ShowDatabases {
  local $databases = shift or croak "Missing array of databases.\n";
  my @titles = qw( Databases );
  my @types = qw( Char );
  my $width = max_length $databases;
  my @lengths = ( $width );
  local( $current_row ) = 0;

  ShowTable \@titles, \@types, \@lengths,
	    sub { &ShowRow( $_[0], \$current_row, $databases ); };
}

=head1 ShowTables 

Show an array of table names.

C<  B<ShowTables> \@tblnames;>

B<ShowTables> is used to display a list of table names, under the column
heading of "Tables".  It is a special case usage of B<ShowTable>.

=cut

sub ShowTables {
  local $tables = shift or croak "Missing array of tables.\n";
  @titles = qw( Tables );
  my @types = qw( Char );
  my $width = max_length $tables;
  my @lengths = ( $width );
  local( $current_row ) = 0;

  ShowTable \@titles,\@types,\@lengths,
	    sub { &ShowRow( $_[0], \$current_row, $tables ); };
}

=head1 ShowColumns 

Display a table of column names, types, and attributes.

C<  B<ShowColumns> \@columns, \@col_types, \@col_lengths, \@col_attrs;>

The B<ShowColumns> subroutine displays a table of column names, types, lengths,
and other attributes in a nicely formatted table.  It is a special case usage
of B<ShowTable>.

The arguments are:

=over 10

=item C<\@I<columns>>

An array of column names.

=item C<\@I<col_types>>

An array of column types names.

=item C<\@I<col_lengths>>

An array of maximum lengths for corresponding columns.

=item C<\@I<col_attrs>>

An array of column attributes array references (ie: an array of arrays).  The 
attributes array for the first column are at "C<$col_attrs-\>[0]>".  The first
attribute of the second column is "C<$col_attrs-\>[1][0]>".

=back

The columns, types, lengths, and attributes are displayed in a table
with the column headings: "Column", "Type", "Length", and "Attributes".
This is a special case usage of B<ShowTable>.

=cut

sub ShowColumns {
  local $col_names      = shift or croak "Missing array of column names.\n";
  local $col_types      = shift or croak "Missing array of column types.\n";
  local $col_lengths    = shift or croak "Missing array of column lengths.\n";
  local $col_attributes = shift or croak "Missing array of column attributes.\n";

  # setup the descriptor arrays
  my @titles = qw(Column Type Length Attributes);
  my @types = qw(varchar varchar int varchar);

  # Do some data conversions before displaying
  # Convert attribute array to a string of attributes
  local @col_attrs = ();
  my $i;
  for ($i = 0; $i <= $#{$col_attributes}; $i++) {
    $col_attrs[$i] = join(', ',@{$col_attributes->[$i]});
  }

  # count the widths, to setup the Column name column width
  my @lengths = ( (max_length $col_names), (max_length $col_types), 
	          (max_length $col_lengths), (max_length \@col_attrs) );

  # Finally, show the darn thing
  ShowTable \@titles, \@types, \@lengths, 
	    sub { &ShowRow($_[0], \$current_row, $col_names, 
			   $col_types, $col_lengths, \@col_attrs); };
}


=head1 ShowBoxTable 

Show tabular data in a box.

C<  B<ShowBoxTable> \@titles, \@types, \@widths, \&row_sub [, \&fmt_sub ];>

The B<ShowBoxTable> displays tabular data in titled columns using a "box" 
of ASCII graphics, looking something like this:
 
 +------------+----------+-----+----------+
 | Column1    | Column2  | ... | ColumnN  |
 +------------+----------+-----+----------+
 | Value11    | Value12  | ... | Value 1M |
 | Value21    | Value22  | ... | Value 2M |
 | Value31    | Value32  | ... | Value 3M |
 |  ...       |  ...     | ... |  ...     |
 | ValueN1    | ValueN2  | ... | Value NM |
 +------------+----------+-----+----------+

The arguments are the same as with C<ShowTable>.  If the C<@titles> array
is empty, the header row is omitted.

=cut

sub ShowBoxTable {
    my $titles      = shift or croak "Missing column names array.\n";
    my $types       = shift or croak "Missing column types array.\n";
    my $col_widths  = shift or croak "Missing column width array.\n";
    my $row_sub     = shift or croak "Missing row sub array.\n";
    my $fmt_sub     = shift || \&ShowTableValue;

    my $rewindable  = &$row_sub(1);	# see if data is rewindable

    my ($num_cols, $widths, $precision, $max_widths) = 
    	&calc_widths($col_widths, $titles, $rewindable, $row_sub);

    my $width = 1;
    my $dashes = ' +';
    my $title_line = ' |';
    my $title;
    my $fmt = ' |';		# initial format string
    my $c;

    # Compose the box header
    for ($c = 0; $c <= $num_cols; $c++) {
	$width = $max_widths->[$c];	# get previously calculated max col width
	$width += 2; 			# account for a blank on either
					# side of each value
	$dashes .= ('-' x $width);
	$dashes .= '+';

	next if $#$titles < 0;
	$title = center $titles->[$c], $width;
	$title_line .= $title;
	$title_line .= '|';
    }
    out $dashes;
    if ($#$titles >= 0) {
	out $title_line;
	out $dashes;
    }

    my @values;
    my @prefix = (" ", ">");
    my @suffix = (" |", "<|");
    my @cell;

    # loop over the data, formatting it into cells, one row at a time.
    while (defined((@values) = &$row_sub(0))) {
	# first pass -- format each value into a string
	@cell = ();
	for ($c = 0; $c <= $#values; $c++) {
	    $cell[$c] = &$fmt_sub($values[$c], $types->[$c], 0,
				  $widths->[$c], $precision->[$c]);
	}
	# second pass -- output each cell, wrapping if necessary
	my $will_wrap;
	my $wrapped = 0;
	do { $will_wrap = 0;
	    put " |";		# start a line
	    for ($c = 0; $c <= $#cell; $c++) {
		$will_wrap |= &putcell(\@cell, $c, $max_widths->[$c],
				       \@prefix, \@suffix, $wrapped);
	    }
	    out "";
	    $wrapped++;
	} while ($will_wrap);
    }
    out $dashes;
    out "";
}


=head1 ShowSimpleTable 

Display a table of data using a simple table format.

C<  B<ShowSimpleTable> \@titles, \@types, \@widths, \&row_sub [, \&fmt_sub];>

The B<ShowSimpleTable> subroutine formats data into a simple table of aligned
columns, in the following example:

   Column1  Column2  Column3
   -------  -------  -------
   Value1   Value2   Value3
   Value12  Value22  Value32

Columns are auto-sized by the data's widths, plus two spaces between columns.
Values which are too long for the maximum colulmn width are wrapped within
the column.

=cut

sub ShowSimpleTable {

    my $titles      = shift or croak "Missing column names array.\n";
    my $types       = shift or croak "Missing column types array.\n";
    my $col_widths  = shift or croak "Missing column width array.\n";
    my $row_sub     = shift or croak "Missing row sub array.\n";
    my $fmt_sub     = shift || \&ShowTableValue;

    my $rewindable  = &$row_sub(1);		# see if data is rewindable

    my ($num_cols, $widths, $precision, $max_widths) = 
    	&calc_widths($col_widths, $titles, $rewindable, $row_sub);

    my $width  = 1;
    my $dashes      = ' ';
    my $title_line  = ' ';
    my $title ;
    my $postfix = shift;
    my $c ;

    # Calculate the maximum widths
    for ($c = 0; $c <= $num_cols; $c++) {
	$width = $max_widths->[$c];
	$dashes .= ('-' x $width);
	$dashes .= '  ';

	next if $#$titles < 0;
	$title = center $titles->[$c], $width;
	$title_line .= $title;
	$title_line .= '  ';

    }
    out $title_line if $#$titles >= 0;
    out $dashes;

    my @values;
    my @prefix = (" ", ">");
    my @suffix = (" ", "<");

    while (defined((@values) = &$row_sub(0))) {
	# first pass -- format each value into a string
	my @cell;
	for ($c = 0; $c <= $#values; $c++) {
	    $cell[$c] = &$fmt_sub($values[$c], $types->[$c], 0,
				  $widths->[$c], $precision->[$c]);
	}
	# second pass -- output each cell, wrapping if necessary
	my $will_wrap;
	my $wrapped = 0;
	do { $will_wrap = 0;
	    for ($c = 0; $c <= $#cell; $c++) {
		$will_wrap |= &putcell(\@cell, $c, $max_widths->[$c],
		             	       \@prefix, \@suffix, $wrapped);
	    }
	    out "";
	    $wrapped++;
	} while ($will_wrap);
    }
    out "";
}

=head1 ShowHTMLTable 

Display a table of data nicely using HTML tables.

C<  B<ShowHTMLTable> \@titles, \@types, \@widths, \&row_sub [, \&fmt_sub];>

The B<ShowHTMLTable> displays one or more rows of columns of data using the HTML
C<\<TABLE\>> feature.  The arguments are described in L<"ShowTable">.

If the C<@titles> array is empty, no header row is generated.

There is a variable which controls if and how hypertext links are generated
within the table:

=over 10

=item B<%URL_Keys>

This is a hash array of column names (titles) and corresponding base
URLs.  The values of any columns occuring as keys in the hash array will
be generated as hypertext anchors using the associated base URL and the
column value as a querystring for the "C<val>" parameter. 

=back

For example, if we define the array:

    $base_url = "http://www.$domain/cgi/lookup";
    %url_cols = ('Author' => $base_url,
		 'Name'   => $base_url);

Then, the values in the C<Author> column will be generated with the following
HTML text:

    <A HREF="http://www.$domain/cgi/lookup?col=Author?val=somevalue>somevalue</A>

and the values in the C<Name> column will be generated with the URL:

    <A HREF="http://www.$domain/cgi/lookup?col=Name?val=othervalue>othervalue</A>

=cut

sub ShowHTMLTable {
    my $titles     = shift or croak "Missing column names array.\n";
    my $types      = shift or croak "Missing column types array.\n";
    my $col_widths = shift or croak "Missing column width array.\n";
    my $row_sub    = shift or croak "Missing row sub array.\n";
    my $fmt_sub    = shift || \&ShowTableValue;

    my $rewindable = &$row_sub(1);		# see if rewindable

    my ($num_cols, $widths, $precision, $max_widths) = 
	&calc_widths($col_widths, $titles, $rewindable, $row_sub);

    my $width  = 1;
    my $total_width;
    my $title_line;
    my $title;
    my $c;

    out "<TABLE BORDER=1>\n<TR>" ;
    map { $total_width += $_; } @$max_widths;
    for ($c = 0; $c <= $num_cols; $c++) {
	$width = $max_widths->[$c];
	my $pct_width = int(100 * $width/$total_width);
	$title_line .= " <TH ALIGN=CENTER WIDTH=$pct_width%%>";
	$title_line .= &htmltext($titles->[$c]) if $#$titles >= 0;
	$title_line .= "</TH>\n";
    }
    out $title_line;
    out "</TR>";

    my ($chartype, $href, $val);
    while (defined((@values) = &$row_sub(0))) {
	out "<TR>";
	put " ";
	# Walk through the values
	for ($c = 0; $c <= $#values; $c++) {
	    put "<TD";
	    if (defined($val = $values[$c])) {	# only worry about defined values

		# In HTML mode, all CHAR and TEXT data must be possibly
		# escaped to protect HTML syntax "<", ">", "\", and "&".
		$val = &htmltext($val) if ($chartype = $types->[$c] =~ /char|text/i);

		put " ALIGN=%s>", ($chartype ? 'LEFT' : 'RIGHT');
		if ($#$titles >= 0 && ($href = $URL_Keys{$titles->[$c]})) {
		    put "<A HREF=\"%s?col=%s?val=%s\">",$href,$titles->[$c],$val;
		}
		$val = &$fmt_sub($val, $types->[$c], 0, $widths->[$c], $precision->[$c]);
		$val =~ s/^\s+//;		# don't try to align
		$val =~ s/\s+$//;
		put $val;
		put "</A>" if $href;
	    } else {
		put ">";
	    }
	    put "</TD>";
	}
	out "";
	out "</TR>";
    }
    out "</TABLE>";
}

=head1 ShowListTable

Display a table of data using a list format.

C<  B<ShowListTable> \@titles, \@types, \@widths, \&row_sub [, \&fmt_sub];>

In I<List> mode, columns (called "fields" in List mode) are displayed
wth a field name and value pair per line, with records being one or
more fields .  In other words, the output of a table would
look something like this:

    Field1-1: Value1-1
    Field1-2: Value1-2
    Field1-3: Value1-3
    ...
    Field1-N: Value1-M
    <empty line>
    Field2-1: Value2-1
    Field2-2: Value2-2
    Field2-3: Value2-3
    ...
    Field2-N: Value2-N
    ...
    FieldM-1: ValueM-1
    FieldM-2: ValueM-2
    ...
    FieldM-N: ValueM-N
    <empty line>
    <empty line>

Characteristics of I<List> mode:

=over 10

=item *

two empty lines indicate the end of data.

=item *

An empty field (column) has a label, but no data.

=item *

A long line can be continue by a null field (column):

    Field2: blah blah blah
          : blah blah blah

=item *

On a continuation, the null field is an arbitrary number of leading
white space, a colon ':', and exactly one blank, followed by the
continued text.

=item *

Embedded newlines are indicated by the escape mechanism "\n".
Similarly, embedded tabs are indicated with "\t", returns with "\r". 

=item *

If the C<@Titles> array is empty, the field names "C<Field NN>" are used
instead.

=over

=cut

sub ShowListTable {

    my $titles     = shift or croak "Missing column names array.\n";
    my $types      = shift or croak "Missing column types array.\n";
    my $col_widths = shift or croak "Missing column width array.\n";
    my $row_sub    = shift or croak "Missing row sub array.\n";
    my $fmt_sub    = shift || \&ShowTableValue;

    my $rewindable = &$row_sub(1);	# init the row pointer

    my ($num_cols, $widths, $precision, $max_widths) = 
	&calc_widths($col_widths, $titles, $rewindable, $row_sub);

    my $fmt = sprintf("%%-%ds : %%s\n", ($#$titles >= 0 ? &max_length($titles) : 8));
    my @values;
    my ($value, $c, $cut, $line);
    my $col_limit = ($Term_Columns || $ENV{'COLUMNS'} || 80) - 2;

    while (defined((@values) = &$row_sub(0))) {
	for ($c = 0; $c <= $#values; $c++) {
	    # get this column's title
	    $title = $#$titles >= 0 ? $titles->[$c] : sprintf("Field %d", $c+1);
	    my $type  = $types->[$c];
	    my $width = $widths->[$c] || length($title);
	    my $prec  = $precision->[$c];
	    $value = &$fmt_sub($values[$c], $title, $type, 0, $width, $prec);
	    while (length($value)) {
		if (length($value) > ($cut = $col_limit)) {
		    $line = substr($value, 0, $cut);
		    if ($line =~ m/([-,;? \t])([^-,;? \t]*)$/ && 
			length($2) <= $List_Wrap_Margin) {
			$cut = $col_limit - length($2);
			$line = substr($value, 0, $cut);
		    }
		    ($value = substr($value, $cut)) =~ s/^\s+//;
		} else {
		    $line = $value;
		    $value = '';
		}
		out $fmt, $title, $line;
		$title = '';
	    }
	}
	out "";
    }
}

=head1 ShowTableValue

Prepare and return a formatted representation of a value.  A value
argument, using its corresponding type, effective width, and precision
is formatted into a field of a given maximum width. 

C<  $fmt = B<ShowTableValue> $value, $type, $max_width, $width, $precision;>

=over 10

=item I<$value>

The value to be formatted.

=item I<$type>

The type name of the value; eg: C<char>, C<varchar>, C<int>, etc.

=item I<$max_width>

The maximum width of the formatted text.

=item I<$width>

The default width of the value, obtained from the width specification of the
column in which this value occurs.

=item I<$precision>

The precision specification, if any, from the column width specification.

=back

=cut
    
sub ShowTableValue { 
  my $value     = shift;
  my $type      = shift;
  my $max_width = shift;
  my $width     = shift || $max_width;
  my $prec      = shift || 0;
  my $fmt       = ($Type2Format{lc($type)} || $Type2Format{'char'});
  $width = min($width, $max_width);
  $fmt = sprintf ($fmt,$width,$prec);
  my $str = sprintf($fmt,$value);
  if ($max_width > 0) {
    # right align the value if any kind of number
    $str = sprintf("%${max_width}s", $str) if $type =~ /int|float|real|numeric/;
    $str = substr($str,0,$max_width);
  }
  $str;
}

%Type2Format = (
  'char'	=> '%%-%ds',
  'varchar'	=> '%%-%ds',
  'symbol'	=> '%%-%ds',
  'tinyint'	=> '%%%dd',
  'shortint'	=> '%%%dd',
  'int'		=> '%%%dd',
  'real'	=> '%%%d.%df',
  'float'	=> '%%%d.%df',
  'numeric'	=> '%%%d.%df',
  'text'	=> '%%-%ds',
  );

=head1 VARIABLES

The following variables may be set by the user to affect the display (with
the defaults enclosed in square brackets [..]):

=over 10

=item C<$B<Show_Mode>> [Box]

This is the default display mode when using B<ShowTable>.  The
environment variable, C<$ENV{'SHOWMODE'}>, is used when this variable is
null or the empty string.  The possible values for this variable are:
"Box", "List", "Table", and "HTML".  Case is insignificant.

=item C<$B<List_Wrap_Margin>> [2]

This variable's value determines how large a margin to keep before wrarpping a
long value's display in a column.  This value is only used in "List" mode.

=item C<$B<Term_Columns>> [80]

This variable, used in "List" mode, is used to determine how long an output line
may be before wrapping it.  The environment variable, C<$ENV{'COLUMNS'}>, is
used to define this value when it is null.

=item C<%B<URL_Keys>>

In HTML mode, this variable is used to recognize which columns are to be displayed
with a corresponding hypertext anchor.  See L<"ShowHTMLTable"> for more details.

=back

##############################

=head1 INTERNAL SUBROUTINES

=head1 calc_widths

C<  ($num_cols, $widths, $precision, $max_widths) = 
      &B<calc_widths>( $widthspec, $titles, $rewindable, $row_sub);>

=over 10

=item I<$num_cols>

is the number of columns in the data.  If the data is not rewindable,
this is computed as the maximum of the number of elements in the
I<$widthspec> array and the number of elements in the I<$titles>
array.  When the data is rewindable, this is the maximum of the number
of columns of each row of data.

=item I<$widths>

is the default column widths array ref, without the precision specs 
(if any).

=item I<$precision>

is the precision component (if any) of the original I<$widthspec>
array ref.

=item I<$max_widths>

is the ref to the array of maximum widths for the given columns.

=item I<$widthspec>

The original width (or length) values, either as an integer, or a string
value of "I<width>.I<precision>".

=item I<$titles>

The array ref to the column's titles; used to determine the minimum
acceptable width, as well as the default number of columns.  If the
C<$titles> array is empty, then the C<$widthspec> array is used to
determine the default number of columns.

=item I<$rewindable>

A flag indicating whether or not the data being formatted is rewindable.
If this is true, a pass over the data will be done in order to calculate
the maximum lengths of the actual data, rather than just rely on the
declared column lengths.

=item I<$row_sub>

The code reference to the subroutine which returns the data; invoked
only if I<$rewindable> is non-null.

=back

This subroutine scans the width specification, creating two new arrays
of the column width and precision (if any).  In addition, an array of
maximum column widths is calculated from the default column width, the
column title widths, and, when possible, the actual length of the data.

This function is used by all of the IB<ShowTable> subroutines.

=cut

sub calc_widths {
    my $widthspec  = shift;
    my $titles     = shift;
    my $rewindable = shift;
    my $row_sub    = shift;

    my @precision = @$widthspec;
    foreach (@precision) { s/^\d+\.(\d+)/$1/; }

    my @widths;
    if ($#$widthspec) {
	@widths = @$widthspec;
	grep(s/\.\d+$//,@widths);	# remove any precision values
    } else {				# no widthspec, use the title
	@widths = map length, @$titles;	# lengths
    }

    # This is the maximum number of columns right now
    my $num_cols = max $#$titles, $#widths;

    my @max_widths;			# array of max widths
    my $c;

    # If the data is rewindable, scan and accumulate *actual* widths for
    # each column, using the title lengths as a minimum.
    if ($rewindable) {
	my @values;

	# use the title lengths as a mininum
	if ($#$titles >= 0) {
	    @max_widths = map length, @$titles;
	} else {			# if no titles, assume zero for now
	    @max_widths = (0) x $#widths;
	}

	while (defined(@values = &$row_sub(0))) {
	    $num_cols = max $num_cols, $#values;	# keep this at the max
	    my $len;
	    for ($c = 0; $c <= $num_cols; $c++) {
		
		$len = length($values[$c]);	# get length

		# In English, the following expression does this:
		# a. take the larger of the the accumulated value for
		#    the current column, and the current value's length;
		# b. take the lesser of (a) and defined column width;
		# c. take the larger of (b) and the title length
		#
		# In other words, don't ever let the column width be
		# less that the width of the title, and not longer than
		# the longest value or the defined column width,
		# whichever is less.
		#
		# Whew!
		$max_widths[$c] = 
		    min( max( $max_widths[$c], 
		    	      length($values[$c])), 
		         max( $widths[$c],
			      length($titles)));
	    }
	}
	if ($#widths < 0) {
	    @widths = @max_widths;
	    $num_cols = max $num_cols, $#widths;
	}
	&$row_sub(1);			# reset the pointer for the next scan
    } else {				# not rewindable
	# use the defined column widths as the maximums.
    	@max_widths = @widths;		

	for ($c = 0; $c <= $num_cols; $c++) {
	    $max_widths[$c] = max($widths[$c], length($titles->[$c]));
	}
    }
    ($num_cols, \@widths, \@precision, \@max_widths);
}

##############################

=head1 putcell

C<  $wrapped = &B<putcell>( \@cells, $c, $cell_width, \@prefix, \@suffix, $wrap_flag );>

Output the contents of an array cell at C<$cell[$c]>, causing text
longer than C<$cell_width> to be saved for output on subsequent calls.
Prefixing the output of each cell's value is a string from the
two-element array C<@prefix>.  Suffixing each cell's value is a string
from the two-element array C<@suffix>.  The first element of either 
array is selected when I<$wrap_flag> is zero or null, or when there is
no more text in the current to be output.  The second element
is selected when I<$wrap_flag> is non-zero, and when there is more text in
the current cell to be output.

In the case of text longer than C<$cell_width>, a non-zero value is
returned. 

Cells with undefined data are not output, nor are the prefix or suffix
strings. 

=cut

sub putcell {
    my $cells      = shift;	# ref to cell array
    my $c          = shift;	# index
    my $cell_width = shift;	# maximum width of the cell
    my $prefix     = shift;	# 2-elt array of prefix strings
    my $suffix     = shift;	# 2-elt array of suffix strings
    my $wrap_flag  = shift;	# non-zero for wrapped lines
    my $fmt        = sprintf("%%s%%-%ds%%s",$cell_width);
    my $more;

    my $v = $cells->[$c];	# get the data
    my $px = 0;			# prefix index
    my $sx = 0;			# suffix index
    if (defined $v) {		# not undef data?
	my $text = $v;		# save the text
	$more = substr($text,$cell_width);
	$v = substr($text,0,$cell_width);

	# wrapping?
	if ($more ne '' &&

	    # See if we can wrap on a word boundary, instead of 
	    # arbitrarily splitting one; 
	    $v =~ /([-,;? \t])([^-,;? \t]*)$/ && 

	    # but also make sure that it is not too long
	    length($2) <= $List_Wrap_Margin) {

	    # Okay, cut on the word boundary, leaving the break char
	    # on the tail end of the current output value
	    my $cut = $cell_width - length($2);
	    $v = substr($text,0,$cut);	# get new value
	    $more = substr($text, $cut);# new remainder
	}
	$cells->[$c] = $more;	# leave the rest for later
	$px = $wrap_flag != 0 && length($v) > 0;
	$sx = length($more) > 0;
    }
    put $fmt,$prefix->[$px],$v,$suffix->[$sx];	# output something (could be blanks)
    $sx;			# leave wrapped flag
}

##############################

=head1 center 

Center a string within a given width.

C<  $field = B<center> $string, $width;>

=cut

sub center {
    my($string,$width) = @_;
    return $string if length($string) >= $width;
    my($pad) = int(($width - length($string))/2);	# pad left half
    my($center) = (' ' x $pad) . $string;
    $pad = $width - length($center);
    $center .= ' ' x $pad;	# pad right half
    $center;			# return with the centered string
}

##############################

=head1 max

Compute the maximum value from a list of values.

C<  $max = &B<max>( @values );>

=cut

sub max {
    my ($max) = shift;
    foreach (@_) { $max = $_ if $max < $_; }
    $max;
}

##############################

=head1 min

Compute the minum value from a list of values.

C<  $min = &B<min>( @values );>

=cut

sub min {
    my ($min) = shift;
    foreach (@_) { $min = $_ if $min > $_; }
    $min;
}

##############################

=head1 max_length

Compute the maximum length of a set of strings in an array reference.

C<  $maxlength = &B<max_length>( \@array_ref );>

=cut

sub max_length {
    my($aref) = shift;
    my(@lens) = map { length } @$aref;
    my($maxlen) = max( @lens );
    $maxlen;
}

=head1 htmltext

Translate regular text for output into an HTML document.  This means
certain characters, such as "&", ">", and "<" must be escaped. 

C<  $output = &B<htmltext>( $input );>

=cut

# htmltext -- translate special text into HTML esacpes
sub htmltext {
    local($_) = @_;
    return undef unless defined($_);
    s/&/&amp;/g; 
    s/\"/&quot;/g;
    s/>/&gt;/g;
    s/</&lt;/g;
    $_;
}

=head1 AUTHOR

Alan K. Stebbens <aks@hub.ucsb.edu>

=cut

#
1;
