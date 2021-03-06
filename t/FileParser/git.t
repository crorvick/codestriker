# Tests to ensure that git patches are handled correctly.

use strict;
use Fatal qw / open close /;
use Test::More tests => 10;

use lib '../../lib';
use Codestriker;
use Codestriker::FileParser::Parser;

# Parse the test git patch file.
my $fh;
open( $fh, '<', '../../test/testtopictexts/git-diff1.txt' );
my @deltas = Codestriker::FileParser::Parser->parse($fh, 'text/plain',
                                                    undef, 111, undef);
close($fh);

# Set what the expected output should be.
my @expected;
push @expected, make_delta(
	filename       => 'builtin-apply.c',
	old_linenumber => 2296,
	new_linenumber => 2296,
        revision       => 'b3fc290',
	description    =>
		'static int apply_data(struct patch *patch, struct stat *st, struct cache_entry *',
	text => <<'END_DELTA',
 
 	strbuf_init(&buf, 0);
 
-	if ((tpatch = in_fn_table(patch->old_name)) != NULL) {
+	if (!(patch->is_copy || patch->is_rename) &&
+	    ((tpatch = in_fn_table(patch->old_name)) != NULL)) {
 		if (tpatch == (struct patch *) -1) {
 			return error("patch %s has been renamed/deleted",
 				patch->old_name);
END_DELTA
);

push @expected, make_delta(
	filename       => 'builtin-apply.c',
	old_linenumber => 2375,
	new_linenumber => 2376,
        revision       => 'b3fc290',
	description    =>
		'static int verify_index_match(struct cache_entry *ce, struct stat *st)',
	text => <<'END_DELTA',
 static int check_preimage(struct patch *patch, struct cache_entry **ce, struct stat *st)
 {
 	const char *old_name = patch->old_name;
-	struct patch *tpatch;
+	struct patch *tpatch = NULL;
 	int stat_ret = 0;
 	unsigned st_mode = 0;
 
END_DELTA
);

push @expected, make_delta(
	filename       => 'builtin-apply.c',
	old_linenumber => 2389,
	new_linenumber => 2390,
        revision       => 'b3fc290',
	description    =>
		'static int check_preimage(struct patch *patch, struct cache_entry **ce, struct s',
	text => <<'END_DELTA',
 		return 0;
 
 	assert(patch->is_new <= 0);
-	if ((tpatch = in_fn_table(old_name)) != NULL) {
+
+	if (!(patch->is_copy || patch->is_rename) &&
+	    (tpatch = in_fn_table(old_name)) != NULL) {
 		if (tpatch == (struct patch *) -1) {
 			return error("%s: has been deleted/renamed", old_name);
 		}
END_DELTA
);

push @expected, make_delta(
	filename       => 'builtin-apply.c',
	old_linenumber => 2399,
	new_linenumber => 2402,
        revision       => 'b3fc290',
	description    =>
		'static int check_preimage(struct patch *patch, struct cache_entry **ce, struct s',
	text => <<'END_DELTA',
 		if (stat_ret && errno != ENOENT)
 			return error("%s: %s", old_name, strerror(errno));
 	}
+
 	if (check_index && !tpatch) {
 		int pos = cache_name_pos(old_name, strlen(old_name));
 		if (pos < 0) {
END_DELTA
);

push @expected, make_delta(
	filename       => 't/t4112-apply-renames.sh',
	old_linenumber => 36,
	new_linenumber => 36,
        revision       => '70a1859',
	description    => 'typedef struct __jmp_buf jmp_buf[1];',
	text           => <<'END_DELTA',
 
 #endif /* _SETJMP_H */
 EOF
+cat >klibc/README <<\EOF
+This is a simple readme file.
+EOF
 
 cat >patch <<\EOF
 diff --git a/klibc/arch/x86_64/include/klibc/archsetjmp.h b/include/arch/cris/klibc/archsetjmp.h
END_DELTA
);

push @expected, make_delta(
	filename       => 't/t4112-apply-renames.sh',
	old_linenumber => 113,
	new_linenumber => 116,
        revision       => '70a1859',
	description    => 'rename to include/arch/m32r/klibc/archsetjmp.h',
	text           => <<'END_DELTA',
 
 -#endif /* _SETJMP_H */
 +#endif /* _KLIBC_ARCHSETJMP_H */
+diff --git a/klibc/README b/klibc/README
+--- a/klibc/README
++++ b/klibc/README
+@@ -1,1 +1,4 @@
+ This is a simple readme file.
++And we add a few
++lines at the
++end of it.
+diff --git a/klibc/README b/klibc/arch/README
+copy from klibc/README
+copy to klibc/arch/README
+--- a/klibc/README
++++ b/klibc/arch/README
+@@ -1,1 +1,3 @@
+ This is a simple readme file.
++And we copy it to one level down, and
++add a few lines at the end of it.
 EOF
 
 find klibc -type f -print | xargs git update-index --add --
END_DELTA
);

# Check that the extracted deltas match what is expected.
is( @deltas, @expected, "Number of deltas in git patch 1" );
for ( my $index = 0; $index < @deltas; $index++ ) {
	is_deeply( $deltas[$index], $expected[$index],
		"Delta $index in git patch 1" );
}

# Check another git patch for new files.
open( $fh, '<', '../../test/testtopictexts/git-diff2.txt' );
@deltas = Codestriker::FileParser::Parser->parse($fh, 'text/plain',
                                                    undef, 111, undef);
close($fh);

@expected = ();
push @expected, make_delta(
	filename       => 'lib/Codestriker/FileParser/GitDiff.pm',
	old_linenumber => 0,
	new_linenumber => 1,
        revision       => '3fd6a56',
        description    => '',
	text => <<'END_DELTA',
+###############################################################################
+# Codestriker: Copyright (c) 2001, 2002, 2003 David Sitsky.
+# All rights reserved.
+# sits@users.sourceforge.net
+#
+# This program is free software; you can redistribute it and modify it under
+# the terms of the GPL.
+
+# Parser object for reading git diffs
+
END_DELTA
);

push @expected, make_delta(
	filename       => 'lib/Codestriker/Http/Input.pm',
	old_linenumber => 332,
	new_linenumber => 332,
        description    => 'sub _untaint_digits($$) {',
        revision       => '01670a2',
	text => <<'END_DELTA',
 sub _untaint_filename($$) {
     my ($self, $name) = @_;
 
-    $self->_untaint($name, '[-_\/\@\w\.\s]+');
+    $self->_untaint($name, '[-_^~{}\/\@\w\.\s]+');
 }
 
 # Untaint a parameter that should be a revision number.
END_DELTA
);

# Check that the extracted deltas match what is expected.
is( @deltas, @expected, "Number of deltas in git patch 2" );
for ( my $index = 0; $index < @deltas; $index++ ) {
	is_deeply( $deltas[$index], $expected[$index],
		"Delta $index in git patch 2" );
}

# Convenience function for creating a delta object.
sub make_delta {

	# Set constant properties for all git deltas.
	my $delta = {};
	$delta->{binary}   = 0;
	$delta->{repmatch} = 0;

	# Apply the passed in arguments.
	my %arg = @_;
	$delta->{filename}       = $arg{filename};
	$delta->{old_linenumber} = $arg{old_linenumber};
	$delta->{new_linenumber} = $arg{new_linenumber};
        $delta->{revision}       = $arg{revision};
	$delta->{description}    = $arg{description};
	$delta->{text}           = $arg{text};

	return $delta;
}
