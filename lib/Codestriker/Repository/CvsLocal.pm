###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# CVS repository class with access to a local repository.

package Codestriker::Repository::CvsLocal;

use strict;
use IPC::Run;

# Constructor, which takes as a parameter the CVSROOT.
sub new ($$) {
    my ($type, $cvsroot) = @_;

    my $self = {};
    $self->{cvsroot} = $cvsroot;
    bless $self, $type;
}

# Retrieve the data corresponding to $filename and $revision.  Store each line
# into $content_array_ref.
sub retrieve ($$$\$) {
    my ($self, $filename, $revision, $content_array_ref) = @_;

    # Open a pipe to the local CVS repository.
    open(CVS, "$Codestriker::cvs -q -d " . $self->{cvsroot} .
	 " co -p -r $revision $filename |")
	|| die "Can't execute CVS command: $!";
    for (my $i = 1; <CVS>; $i++) {
	chop;
	$$content_array_ref[$i] = $_;
    }
    close CVS;
}

# Retrieve the "root" of this repository.
sub getRoot ($) {
    my ($self) = @_;
    return $self->{cvsroot};
}

# Return a URL which views the specified file and revision.
sub getViewUrl ($$$) {
    my ($self, $filename, $revision) = @_;

    # Lookup the file viewer from the configuration.
    my $viewer = $Codestriker::file_viewer->{$self->{cvsroot}};
    return (defined $viewer) ? $viewer . "/" . $filename : "";
}

# Return a string representation of this repository.
sub toString ($) {
    my ($self) = @_;
    return $self->getRoot();
}

# Given a start tag, end tag and a module name, store the text into
# the specified file handle.  If the size of the diff goes beyond the
# limit, then return the appropriate error code.
sub getDiff ($$$$$$) {
    my ($self, $start_tag, $end_tag, $module_name, $fh, $error_file) = @_;

    my @command = ( $Codestriker::cvs, '-q', '-d', $self->{cvsroot},
		    'rdiff', '-u', '-r', $start_tag, '-r', $end_tag,
		    $module_name );

    my $h = IPC::Run::run(\@command, '>', $fh, '2>', ">$error_file");

    return $Codestriker::OK;
}

1;
