###############################################################################
# Codestriker: Copyright (c) 2001, 2002 David Sitsky.  All rights reserved.
# sits@users.sourceforge.net
#
# This program is free software; you can redistribute it and modify it under
# the terms of the GPL.

# Collection of routines for processing the HTTP input.

package Codestriker::Http::Input;

use strict;

use CGI::Carp 'fatalsToBrowser';

use Codestriker::Http::Cookie;

sub _set_property_from_cookie( $$$ );
sub _untaint( $$$ );
sub _untaint_name( $$ );
sub _untaint_digits( $$ );
sub _untaint_filename( $$ );
sub _untaint_revision( $$ );
sub _untaint_email( $$ );
sub _untaint_emails( $$ );
sub _untaint_bug_ids( $$ );

# Default valiue to set the context if it is not set.
my $DEFAULT_CONTEXT = 2;

# Constructor for this class.
sub new($$$) {
    my ($type, $query, $http_response) = @_;
    my $self = {};
    $self->{query} = $query;
    $self->{http_response} = $http_response;
    return bless $self, $type;
}

# Process the CGI parameters, and untaint them.  If any of them look
# suspicious, immediately output an error.
sub process($) {
    my ($self) = @_;

    my $query = $self->{query};
    my %cookie = Codestriker::Http::Cookie->get($query);

    # Retrieve all of the known Codestriker CGI parameters, and check they
    # are valid.
    $self->{action} = $query->param('action');
    $self->{button} = $query->param('button');
    $self->{topic} = $query->param('topic');
    $self->{line} = $query->param('line');
    $self->{context} = $query->param('context');
    $self->{action} = $query->param('action');
    $self->{comments} = $query->param('comments');
    $self->{email} = $query->param('email');
    $self->{topic_text} = $query->param('topic_text');
    $self->{topic_title} = $query->param('topic_title');
    $self->{topic_description} = $query->param('topic_description');
    $self->{reviewers} = $query->param('reviewers');
    $self->{cc} = $query->param('cc');
    $self->{comment_cc} = $query->param('comment_cc');
    $self->{topic_state} = $query->param('topic_state');
    $self->{revision} = $query->param('revision');
    $self->{filename} = $query->param('filename');
    $self->{linenumber} = $query->param('linenumber');
    $self->{mode} = $query->param('mode');
    $self->{bug_ids} = $query->param('bug_ids');
    $self->{new} = $query->param('new');
    $self->{tabwidth} = $query->param('tabwidth');
    $self->{sauthor} = $query->param('sauthor');
    $self->{sreviewer} = $query->param('sreviewer');
    $self->{scc} = $query->param('scc');
    $self->{sbugid} = $query->param('sbugid');
    $self->{stext} = $query->param('stext');
    $self->{stitle} = $query->param('stitle');
    $self->{sdescription} = $query->param('sdescription');
    $self->{scomment} = $query->param('scomment');
    $self->{sbody} = $query->param('sbody');
    $self->{sstate} = $query->param('sstate');
    $self->{version} = $query->param('version');
    $self->{redirect} = $query->param('redirect');
    $self->{a} = $query->param('a');
    $self->{updated} = $query->param('updated');
    $self->{repository} = $query->param('repository');

    # Set things to the empty string rather than undefined.
    $self->{cc} = "" if ! defined $self->{cc};
    $self->{reviewers} = "" if ! defined $self->{reviewers};
    $self->{bug_ids} = "" if ! defined $self->{bug_ids};
    $self->{sstate} = "" if ! defined $self->{sstate};
    $self->{a} = "" if ! defined $self->{a};
    $self->{updated} = 0 if ! defined $self->{updated};
    $self->{repository} = "" if ! defined $self->{repository};

    # Remove those annoying \r's in textareas.
    if (defined $self->{topic_description}) {
	$self->{topic_description} =~ s/\r//g;
    } else {
	$self->{topic_description} = "";
    }

    if (defined $self->{comments}) {
	$self->{comments} =~ s/\r//g;
    } else {
	$self->{comments} = "";
    }

    # Record the file handler for a topic text upload, if any.
    $self->{fh} = $query->upload('topic_file');

    # Set parameter values from the cookie if they are not set.
    $self->_set_property_from_cookie('context', $DEFAULT_CONTEXT);
    $self->_set_property_from_cookie('mode',
				     $Codestriker::default_topic_create_mode);
    $self->_set_property_from_cookie('tabwidth',
				     $Codestriker::default_tabwidth);
    $self->_set_property_from_cookie('email', "");
    $self->_set_property_from_cookie('repository',
				     $Codestriker::default_repository);

    # Untaint the required input.
    $self->_untaint_name('action');
    $self->_untaint_digits('topic');
    $self->_untaint_email('email');
    $self->_untaint_emails('reviewers');
    $self->_untaint_emails('cc');
    $self->_untaint_filename('filename');
    $self->_untaint_revision('revision');
    $self->_untaint_bug_ids('bug_ids');
    $self->_untaint_digits('new');
    $self->_untaint_digits('tabwidth');

    # Canonicalise the bug_ids and email list parameters if required.
    $self->{reviewers} = $self->make_canonical_email_list($self->{reviewers});
    $self->{cc} = $self->make_canonical_email_list($self->{cc});
    $self->{bug_ids} = $self->make_canonical_bug_list($self->{bug_ids});
}

# Return the query object associated with this object.
sub get_query($) {
    my ($self) = @_;

    return $self->{query};
}

# Return the specified parameter.
sub get($$) {
    my ($self, $param) = @_;

    return $self->{$param};
}

# Given a list of email addresses separated by commas and spaces, return
# a canonical form, where they are separated by a comma and a space.
sub make_canonical_email_list($$) {
    my ($type, $emails) = @_;

    if (defined $emails && $emails ne "") {
	return join ', ', split /[\s\n\t,;]+/, $emails;
    } else {
	return $emails;
    }
}

# Given a list of bug ids separated by commas and spaces, return
# a canonical form, where they are separated by a comma and a space.
sub make_canonical_bug_list($$) {
    my ($type, $bugs) = @_;

    if (defined $bugs && $bugs ne "") {
	return join ', ', split /[\s\n\t,;]+/, $bugs;
    } else {
	return "";
    }
}

# Set the specified property from the cookie if it is not set.  If the cookie
# is not set, use the supplied default value.
sub _set_property_from_cookie($$$) {
    my ($self, $name, $default) = @_;

    my %cookie = Codestriker::Http::Cookie->get($self->{query});
    if (! defined $self->{$name} || $self->{$name} eq "") {
	$self->{$name} = exists $cookie{$name} ? $cookie{$name} : $default;
    }
}

# Untain the specified property, against the expected regular expression.
sub _untaint($$$) {
    my ($self, $name, $regexp) = @_;

    my $value = $self->{$name};
    if (defined $value && $value ne "") {
	if ($value !~ /^${regexp}$/) {
	    my $error_message = "Input parameter $name has invalid value: " .
		"\"$value\"";
	    $self->{http_response}->error($error_message);
	}
    } else {
	$self->{$name} = "";
    }
}

# Untaint a parameter which should be a bunch of alphabetical characters and
# underscores.
sub _untaint_name($$) {
    my ($self, $name) = @_;

    $self->_untaint($name, '[A-Za-z_]+');
}
    
# Untaint a parameter which should be a bunch of digits.
sub _untaint_digits($$) {
    my ($self, $name) = @_;

    $self->_untaint($name, '\d+');
}

# Untaint a parameter which should be a valid filename.
sub _untaint_filename($$) {
    my ($self, $name) = @_;

    $self->_untaint($name, '[-_\/\@\w\.\s]+');
}

# Untaint a parameter that should be a revision number.
sub _untaint_revision($$) {
    my ($self, $name) = @_;

    $self->_untaint($name, '[\d\.]+');
}
	    
# Untaint a single email address, which should be a regular email address.
sub _untaint_email($$) {
    my ($self, $name) = @_;

    $self->_untaint($name, '[-_\@\w\.]+');
}

# Untaint a list of email addresses.
sub _untaint_emails($$) {
    my ($self, $name) = @_;

    $self->_untaint($name, '[-_@\w,;\.\s]+');
}

# Untaint a list of bug ids.
sub _untaint_bug_ids($$) {
    my ($self, $name) = @_;

    $self->_untaint($name, '[0-9A-Za-z_;,\s\n\t]+');
}

1;
