###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Factory class for retrieving a repository object.

package Codestriker::Repository::RepositoryFactory;

use strict;

use Codestriker::Repository::CvsLocal;
use Codestriker::Repository::CvsPserver;
use Codestriker::Repository::ViewCvs;
use Codestriker::Repository::CvsWeb;
use Codestriker::Repository::Subversion;
use Codestriker::Repository::Perforce;
use Codestriker::Repository::Vss;

# Factory method for retrieving a Repository object, given a descriptor.
sub get ($$) {
    my ($type, $repository) = @_;

    if (!(defined $repository) || $repository eq "") {
	return undef;
    }

    if ($repository =~ /^\s*(\/.*?)\/*\s*$/) {
	# CVS repository on the local machine.
	return Codestriker::Repository::CvsLocal->new($1, '');
    } elsif ($repository =~ /^\s*:local:([A-z]:[\\\/].*?)\\*\s*$/) {
      # Windoze "local" CVS repository.
	return Codestriker::Repository::CvsLocal->new($1, ':local:');
    } elsif ($repository =~ /^\s*([A-z]:[\\\/].*?)\\*\s*$/) {
      # Windoze CVS repository.
	return Codestriker::Repository::CvsLocal->new($1, '');
    } elsif ($repository =~ /^\s*:pserver:(.*):(.*)@(.*):(.*)\s*$/i) {
	# Pserver repository.
	return Codestriker::Repository::CvsPserver->new($1, $2, $3, $4);
    } elsif ($repository =~ /^\s*(https?:\/\/.*viewcvs\.cgi)\/*\s+(.*?)\/*\s*$/i) {
	# View CVS repository.
	return Codestriker::Repository::ViewCvs->new($1, $2);
    } elsif ($repository =~ /^\s*(https?:\/\/.*cvsweb\.cgi)\/*\s+(.*?)\/*\s*$/i) {
	# CVS web repository.
	return Codestriker::Repository::CvsWeb->new($1, $2);
    } elsif ($repository =~ /^\s*svn:(https?:\/\/.*)\s*$/i) {
	# Subversion repository.
	return Codestriker::Repository::Subversion->new($1);
    } elsif ($repository =~ /^\s*perforce:(.*):(.*)@(.*):(.*)\s*$/i) {
	# Perforce repository.
	return Codestriker::Repository::Perforce->new($1, $2, $3, $4);
    } elsif ($repository =~ /^\s*vss:(.*)$/i) {
	# Visual Source Safe (VSS) repository.
	return Codestriker::Repository::Vss->new($1);
    } else {
	# Unknown repository type.
	print STDERR "Codestriker: Couldn't match repository: \"$repository\"\n";
	return undef;
    }
}

1;
